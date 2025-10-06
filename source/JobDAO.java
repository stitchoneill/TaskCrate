package source;

import java.sql.*;
import java.util.*;
import javax.servlet.ServletContext;

public class JobDAO {

    private final String dbPath;

    public JobDAO(ServletContext context) {
        // where the SQLite DB file is (read from WEB-INF/config.properties)
        this.dbPath = DBConfig.getDbPath(context);
    }

    // open a connection to SQLite
    private Connection connect() throws SQLException {
        try {
            Class.forName("org.sqlite.JDBC");
        } catch (ClassNotFoundException e) {
            throw new SQLException("SQLite JDBC driver not found", e);
        }
        return DriverManager.getConnection("jdbc:sqlite:" + dbPath);
    }

    // add a job + its selected items; reduces stock for those items
    public int addJob(String jobName, String description, String scheduledDate, String status, List<JobItem> jobItems) {
        final String insertJob = "INSERT INTO jobs (job_name, description, scheduled_date, status) VALUES (?, ?, ?, ?)";
        final String insertJobItem = "INSERT INTO job_items (job_id, item_id, quantity_used) VALUES (?, ?, ?)";
        final String decStock = "UPDATE inventory_items SET quantity = quantity - ? WHERE item_id = ?";

        try (Connection conn = connect()) {
            conn.setAutoCommit(false); // keep all inserts/updates together

            // save the job row first
            try (PreparedStatement ps = conn.prepareStatement(insertJob)) {
                ps.setString(1, nvl(jobName));
                ps.setString(2, nvl(description));
                ps.setString(3, nvl(scheduledDate));
                ps.setString(4, nvl(status));
                ps.executeUpdate();
            }

            // get the new job id
            int jobId = -1;
            try (Statement s = conn.createStatement();
                    ResultSet rs = s.executeQuery("SELECT last_insert_rowid()")) {
                if (rs.next())
                    jobId = rs.getInt(1);
            }
            if (jobId <= 0)
                throw new SQLException("Failed to retrieve last_insert_rowid() for jobs insert.");

            // add job items (if any) and reduce stock
            if (jobItems != null && !jobItems.isEmpty()) {
                try (PreparedStatement psItem = conn.prepareStatement(insertJobItem);
                        PreparedStatement psStock = conn.prepareStatement(decStock)) {
                    for (JobItem ji : jobItems) {
                        psItem.setInt(1, jobId);
                        psItem.setInt(2, ji.getItemId());
                        psItem.setInt(3, ji.getQuantityUsed());
                        psItem.addBatch();

                        psStock.setInt(1, ji.getQuantityUsed());
                        psStock.setInt(2, ji.getItemId());
                        psStock.addBatch();
                    }
                    psItem.executeBatch();
                    psStock.executeBatch();
                }
            }

            conn.commit();
            return jobId;
        } catch (SQLException e) {
            e.printStackTrace();
            return -1;
        }
    }

    // list all current jobs (newest first)
    public List<Job> getActiveJobs() {
        List<Job> out = new ArrayList<>();
        final String sql = "SELECT rowid AS job_id, job_name, description, scheduled_date, status " +
                "FROM jobs ORDER BY rowid DESC";
        try (Connection conn = connect();
                PreparedStatement ps = conn.prepareStatement(sql);
                ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Job j = new Job();
                j.setJobId(rs.getInt("job_id"));
                j.setName(rs.getString("job_name"));
                j.setDescription(rs.getString("description"));
                j.setScheduledDate(rs.getString("scheduled_date"));
                j.setStatus(rs.getString("status"));
                out.add(j);
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return out;
    }

    // alias kept for compatibility
    public List<Job> getAllJobs() {
        return getActiveJobs();
    }

    // fetch a single job by id
    public Job getJobById(int jobId) {
        final String sql = "SELECT rowid AS job_id, job_name, description, scheduled_date, status " +
                "FROM jobs WHERE rowid = ?";
        try (Connection conn = connect();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, jobId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    Job j = new Job();
                    j.setJobId(rs.getInt("job_id"));
                    j.setName(rs.getString("job_name"));
                    j.setDescription(rs.getString("description"));
                    j.setScheduledDate(rs.getString("scheduled_date"));
                    j.setStatus(rs.getString("status"));
                    return j;
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return null;
    }

    // update the basic details for a job
    public void updateJob(int jobId, String jobName, String description, String scheduledDate, String status) {
        final String sql = "UPDATE jobs SET job_name = ?, description = ?, scheduled_date = ?, status = ? WHERE rowid = ?";
        try (Connection conn = connect();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, nvl(jobName));
            ps.setString(2, nvl(description));
            ps.setString(3, nvl(scheduledDate));
            ps.setString(4, nvl(status));
            ps.setInt(5, jobId);
            ps.executeUpdate();
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    // get the items currently attached to a job
    public List<JobItem> getJobItems(int jobId) {
        List<JobItem> out = new ArrayList<>();
        final String sql = "SELECT item_id, quantity_used FROM job_items WHERE job_id = ?";
        try (Connection conn = connect();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, jobId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    JobItem ji = new JobItem();
                    ji.setJobId(jobId);
                    ji.setItemId(rs.getInt("item_id"));
                    ji.setQuantityUsed(rs.getInt("quantity_used"));
                    out.add(ji);
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return out;
    }

    // replace a job's items in one go (also adjusts stock differences)
    public void replaceJobItems(int jobId, List<JobItem> newItems) {
        Map<Integer, Integer> newMap = toQtyMap(newItems);

        final String fetch = "SELECT item_id, quantity_used FROM job_items WHERE job_id = ?";
        final String delAll = "DELETE FROM job_items WHERE job_id = ?";
        final String ins = "INSERT INTO job_items (job_id, item_id, quantity_used) VALUES (?, ?, ?)";
        final String stock = "UPDATE inventory_items SET quantity = quantity + ? WHERE item_id = ?";

        try (Connection conn = connect()) {
            conn.setAutoCommit(false);

            // read current items -> map itemId -> qty
            Map<Integer, Integer> curMap = new HashMap<>();
            try (PreparedStatement ps = conn.prepareStatement(fetch)) {
                ps.setInt(1, jobId);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        curMap.put(rs.getInt("item_id"), rs.getInt("quantity_used"));
                    }
                }
            }

            // adjust stock by the delta between new and old
            try (PreparedStatement psStock = conn.prepareStatement(stock)) {
                Set<Integer> keys = new HashSet<>();
                keys.addAll(curMap.keySet());
                keys.addAll(newMap.keySet());
                for (Integer itemId : keys) {
                    int oldQ = curMap.getOrDefault(itemId, 0);
                    int newQ = newMap.getOrDefault(itemId, 0);
                    int delta = newQ - oldQ; // positive delta means we used more (so reduce stock)
                    if (delta != 0) {
                        psStock.setInt(1, -delta); // invert because +delta used -> -delta stock
                        psStock.setInt(2, itemId);
                        psStock.addBatch();
                    }
                }
                psStock.executeBatch();
            }

            // wipe old items and insert the new set
            try (PreparedStatement psDel = conn.prepareStatement(delAll)) {
                psDel.setInt(1, jobId);
                psDel.executeUpdate();
            }
            if (!newMap.isEmpty()) {
                try (PreparedStatement psIns = conn.prepareStatement(ins)) {
                    for (Map.Entry<Integer, Integer> e : newMap.entrySet()) {
                        psIns.setInt(1, jobId);
                        psIns.setInt(2, e.getKey());
                        psIns.setInt(3, e.getValue());
                        psIns.addBatch();
                    }
                    psIns.executeBatch();
                }
            }

            conn.commit();
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    // archive one job into history; optionally restock its items
    public void archiveJob(int jobId, String finalStatus, boolean restock) throws SQLException {
        try (Connection conn = connect()) {
            conn.setAutoCommit(false);
            archiveJobTx(conn, jobId, finalStatus, restock);
            conn.commit();
        }
    }

    // archive many jobs in one transaction
    public void archiveJobs(Collection<Integer> jobIds, String finalStatus, boolean restock) throws SQLException {
        if (jobIds == null || jobIds.isEmpty())
            return;
        try (Connection conn = connect()) {
            conn.setAutoCommit(false);
            for (Integer id : jobIds) {
                if (id != null)
                    archiveJobTx(conn, id, finalStatus, restock);
            }
            conn.commit();
        }
    }

    // do the archiving work (copy to history tables, restock if needed, then delete live rows)
    private void archiveJobTx(Connection conn, int jobId, String finalStatus, boolean restock) throws SQLException {
        String name = null, desc = null, date = null;
        // read the job’s basic info
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT job_name, description, scheduled_date FROM jobs WHERE rowid = ?")) {
            ps.setInt(1, jobId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next())
                    return;
                name = rs.getString(1);
                desc = rs.getString(2);
                date = rs.getString(3);
            }
        }

        // write the job into history
        try (PreparedStatement ins = conn.prepareStatement(
                "INSERT OR REPLACE INTO jobs_history (job_id, job_name, description, scheduled_date, status) " +
                        "VALUES (?, ?, ?, ?, ?)")) {
            ins.setInt(1, jobId);
            ins.setString(2, nvl(name));
            ins.setString(3, nvl(desc));
            ins.setString(4, nvl(date));
            ins.setString(5, nvl(finalStatus));
            ins.executeUpdate();
        }

        // copy job items to history and optionally restock
        try (PreparedStatement sel = conn.prepareStatement(
                "SELECT item_id, quantity_used FROM job_items WHERE job_id = ?");
                PreparedStatement insHi = conn.prepareStatement(
                        "INSERT INTO job_items_history (job_id, item_id, quantity_used) VALUES (?, ?, ?)");
                PreparedStatement updStock = conn.prepareStatement(
                        "UPDATE inventory_items SET quantity = quantity + ? WHERE item_id = ?")) {

            sel.setInt(1, jobId);
            try (ResultSet rs = sel.executeQuery()) {
                while (rs.next()) {
                    int itemId = rs.getInt(1);
                    int qty = rs.getInt(2);

                    insHi.setInt(1, jobId);
                    insHi.setInt(2, itemId);
                    insHi.setInt(3, qty);
                    insHi.addBatch();

                    if (restock && qty > 0) {
                        updStock.setInt(1, qty);
                        updStock.setInt(2, itemId);
                        updStock.addBatch();
                    }
                }
            }
            insHi.executeBatch();
            if (restock)
                updStock.executeBatch();
        }

        // remove from live tables now that history is saved
        try (PreparedStatement delItems = conn.prepareStatement("DELETE FROM job_items WHERE job_id = ?");
                PreparedStatement delJob = conn.prepareStatement("DELETE FROM jobs WHERE rowid = ?")) {
            delItems.setInt(1, jobId);
            delItems.executeUpdate();
            delJob.setInt(1, jobId);
            delJob.executeUpdate();
        }
    }

    // read job rows from the history table
    public List<Job> getHistoryJobs() {
        List<Job> out = new ArrayList<>();
        final String sql = "SELECT job_id, job_name, description, scheduled_date, status " +
                "FROM jobs_history ORDER BY job_id DESC";
        try (Connection conn = connect();
                PreparedStatement ps = conn.prepareStatement(sql);
                ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Job j = new Job();
                j.setJobId(rs.getInt("job_id"));
                j.setName(rs.getString("job_name"));
                j.setDescription(rs.getString("description"));
                j.setScheduledDate(rs.getString("scheduled_date"));
                j.setStatus(rs.getString("status"));
                out.add(j);
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return out;
    }

    // read job item rows from the history table for one job
    public List<JobItem> getHistoryJobItems(int jobId) {
        List<JobItem> out = new ArrayList<>();
        final String sql = "SELECT item_id, quantity_used FROM job_items_history WHERE job_id = ?";
        try (Connection conn = connect();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, jobId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    JobItem ji = new JobItem();
                    ji.setJobId(jobId);
                    ji.setItemId(rs.getInt("item_id"));
                    ji.setQuantityUsed(rs.getInt("quantity_used"));
                    out.add(ji);
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return out;
    }

    // hard delete one job (optionally put stock back first)
    public void deleteJob(int jobId, boolean restock) {
        try (Connection conn = connect()) {
            conn.setAutoCommit(false);
            deleteJobTx(conn, jobId, restock);
            conn.commit();
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    // hard delete many jobs
    public void deleteJobs(Collection<Integer> jobIds, boolean restock) {
        if (jobIds == null || jobIds.isEmpty())
            return;
        try (Connection conn = connect()) {
            conn.setAutoCommit(false);
            for (Integer id : jobIds) {
                if (id != null)
                    deleteJobTx(conn, id, restock);
            }
            conn.commit();
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    // soft delete a single job (status -> Deleted) and restock items
    public void softDeleteJob(int jobId) {
        final String setDeleted = "UPDATE jobs SET status = ? WHERE rowid = ?";
        try (Connection conn = connect();
                PreparedStatement upd = conn.prepareStatement(setDeleted)) {
            conn.setAutoCommit(false);
            restockItemsForJob(conn, jobId);
            upd.setString(1, "Deleted");
            upd.setInt(2, jobId);
            upd.executeUpdate();
            conn.commit();
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    // soft delete many jobs at once
    public void softDeleteJobs(List<Integer> ids) {
        if (ids == null || ids.isEmpty())
            return;
        final String setDeleted = "UPDATE jobs SET status = ? WHERE rowid = ?";
        try (Connection conn = connect();
                PreparedStatement upd = conn.prepareStatement(setDeleted)) {
            conn.setAutoCommit(false);
            for (int id : ids) {
                restockItemsForJob(conn, id);
                upd.setString(1, "Deleted");
                upd.setInt(2, id);
                upd.addBatch();
            }
            upd.executeBatch();
            conn.commit();
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    // just set a job’s status value
    public void markJobStatus(int jobId, String status) {
        final String sql = "UPDATE jobs SET status = ? WHERE rowid = ?";
        try (Connection conn = connect();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, status);
            ps.setInt(2, jobId);
            ps.executeUpdate();
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    // internal: delete a job + items, optionally restocking first
    private void deleteJobTx(Connection conn, int jobId, boolean restock) throws SQLException {
        if (restock) {
            final String q = "SELECT item_id, quantity_used FROM job_items WHERE job_id = ?";
            try (PreparedStatement ps = conn.prepareStatement(q)) {
                ps.setInt(1, jobId);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        int itemId = rs.getInt("item_id");
                        int qty = rs.getInt("quantity_used");
                        adjustStockTx(conn, itemId, qty);
                    }
                }
            }
        }
        try (PreparedStatement ps1 = conn.prepareStatement("DELETE FROM job_items WHERE job_id = ?");
                PreparedStatement ps2 = conn.prepareStatement("DELETE FROM jobs WHERE rowid = ?")) {
            ps1.setInt(1, jobId);
            ps1.executeUpdate();
            ps2.setInt(1, jobId);
            ps2.executeUpdate();
        }
    }

    // internal: add delta to an item's quantity
    private void adjustStockTx(Connection conn, int itemId, int delta) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement(
                "UPDATE inventory_items SET quantity = quantity + ? WHERE item_id = ?")) {
            ps.setInt(1, delta);
            ps.setInt(2, itemId);
            ps.executeUpdate();
        }
    }

    // internal: for a job, put all item quantities back
    private void restockItemsForJob(Connection conn, int jobId) throws SQLException {
        final String sel = "SELECT item_id, quantity_used FROM job_items WHERE job_id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sel)) {
            ps.setInt(1, jobId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    int itemId = rs.getInt("item_id");
                    int qty = rs.getInt("quantity_used");
                    adjustStockTx(conn, itemId, qty);
                }
            }
        }
    }

    // null-safe string (never return null)
    private static String nvl(String s) {
        return (s == null) ? "" : s;
    }

    // turn a list of JobItem into a map of itemId -> total qty
    private static Map<Integer, Integer> toQtyMap(List<JobItem> list) {
        Map<Integer, Integer> m = new HashMap<>();
        if (list != null) {
            for (JobItem ji : list) {
                if (ji == null)
                    continue;
                int itemId = ji.getItemId();
                int qty = Math.max(0, ji.getQuantityUsed());
                m.put(itemId, m.getOrDefault(itemId, 0) + qty);
            }
        }
        return m;
    }
}
