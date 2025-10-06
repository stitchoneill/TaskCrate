package source;

import java.sql.*;
import java.util.*;
import javax.servlet.ServletContext;

public class InventoryDAO {
    private final String dbPath;

    public InventoryDAO(ServletContext context) {
        // where the SQLite file lives (from WEB-INF/config.properties)
        this.dbPath = DBConfig.getDbPath(context);
        System.out.println("InventoryDAO using DB = " + this.dbPath);
    }

    // open a connection to the SQLite DB
    private Connection connect() throws SQLException {
        try {
            Class.forName("org.sqlite.JDBC");
        } catch (ClassNotFoundException e) {
            throw new SQLException(e);
        }
        return DriverManager.getConnection("jdbc:sqlite:" + dbPath);
    }

    // quick helper: decide the status from a number and its low-stock threshold
    private static String statusForQty(int q, int threshold) {
        if (q <= 0)
            return "out_of_stock";
        if (q <= threshold)
            return "low_stock";
        return "in_stock";
    }

    // default low-stock threshold if none is set
    private static final int DEFAULT_THRESHOLD = 2;

    // after any stock change, recalc and save the status for one item
    private void updateStatusForItem(Connection conn, int itemId) throws SQLException {
        try (PreparedStatement sel = conn.prepareStatement(
                "SELECT quantity, low_stock_threshold FROM inventory_items WHERE item_id=?");
                PreparedStatement upd = conn.prepareStatement(
                        "UPDATE inventory_items SET status=? WHERE item_id=?")) {
            sel.setInt(1, itemId);
            try (ResultSet rs = sel.executeQuery()) {
                if (rs.next()) {
                    int q = rs.getInt("quantity");
                    int th = rs.getInt("low_stock_threshold");
                    String st = statusForQty(q, th);
                    upd.setString(1, st);
                    upd.setInt(2, itemId);
                    upd.executeUpdate();
                }
            }
        }
    }

    // list everything (newest first by id)
    public List<InventoryItem> getAllItems() {
        List<InventoryItem> items = new ArrayList<>();
        String sql = "SELECT item_id, name, description, quantity, status, low_stock_threshold "
                + "FROM inventory_items ORDER BY item_id DESC";
        try (Connection conn = connect();
                PreparedStatement stmt = conn.prepareStatement(sql);
                ResultSet rs = stmt.executeQuery()) {
            while (rs.next()) {
                InventoryItem item = new InventoryItem();
                item.setItemId(rs.getInt("item_id"));
                item.setName(rs.getString("name"));
                item.setDescription(rs.getString("description"));
                item.setQuantity(rs.getInt("quantity"));
                item.setStatus(rs.getString("status"));
                item.setLowStockThreshold(rs.getInt("low_stock_threshold"));
                items.add(item);
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return items;
    }

    // fetch a single item by its id
    public InventoryItem getItemById(int itemId) {
        String sql = "SELECT item_id, name, description, quantity, status, low_stock_threshold "
                + "FROM inventory_items WHERE item_id = ?";
        try (Connection conn = connect();
                PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, itemId);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    InventoryItem it = new InventoryItem();
                    it.setItemId(rs.getInt("item_id"));
                    it.setName(rs.getString("name"));
                    it.setDescription(rs.getString("description"));
                    it.setQuantity(rs.getInt("quantity"));
                    it.setStatus(rs.getString("status"));
                    it.setLowStockThreshold(rs.getInt("low_stock_threshold"));
                    return it;
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return null;
    }

    // add a new item and return the new id
    public int addItem(InventoryItem item) {
        String sql = "INSERT INTO inventory_items "
                + "(name, description, quantity, status, low_stock_threshold) VALUES (?,?,?,?,?)";

        // make sure threshold and status always have sensible values
        int th = (item.getLowStockThreshold() > 0) ? item.getLowStockThreshold() : DEFAULT_THRESHOLD;
        String status = (item.getStatus() == null || item.getStatus().isEmpty())
                ? statusForQty(item.getQuantity(), th)
                : item.getStatus();

        try (Connection conn = connect()) {
            conn.setAutoCommit(false); // keep it tidy as one unit of work

            // insert the new row
            try (PreparedStatement ins = conn.prepareStatement(sql)) {
                ins.setString(1, item.getName());
                ins.setString(2, item.getDescription());
                ins.setInt(3, item.getQuantity());
                ins.setString(4, status);
                ins.setInt(5, th);
                ins.executeUpdate();
            }

            // get the id SQLite just created
            int newId = -1;
            try (Statement s = conn.createStatement();
                    ResultSet rs = s.executeQuery("SELECT last_insert_rowid()")) {
                if (rs.next())
                    newId = rs.getInt(1);
            }

            conn.commit();
            return newId;
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return -1;
    }

    // update name/desc/qty/status/threshold for an item
    public void updateItem(InventoryItem item) {
        int th = (item.getLowStockThreshold() > 0) ? item.getLowStockThreshold() : DEFAULT_THRESHOLD;
        String st = (item.getStatus() == null || item.getStatus().isEmpty())
                ? statusForQty(item.getQuantity(), th)
                : item.getStatus();

        String sql = "UPDATE inventory_items SET name=?, description=?, quantity=?, status=?, low_stock_threshold=? "
                + "WHERE item_id=?";
        try (Connection conn = connect();
                PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, item.getName());
            stmt.setString(2, item.getDescription());
            stmt.setInt(3, item.getQuantity());
            stmt.setString(4, st);
            stmt.setInt(5, th);
            stmt.setInt(6, item.getItemId());
            stmt.executeUpdate();
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    // remove an item completely
    public void deleteItem(int itemId) {
        String sql = "DELETE FROM inventory_items WHERE item_id = ?";
        try (Connection conn = connect();
                PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, itemId);
            stmt.executeUpdate();
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    // reduce stock by a certain amount (only if enough is available)
    public void deductStock(int itemId, int amount) {
        String sql = "UPDATE inventory_items SET quantity = quantity - ? WHERE item_id = ? AND quantity >= ?";
        try (Connection conn = connect();
                PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, amount);
            stmt.setInt(2, itemId);
            stmt.setInt(3, amount);
            stmt.executeUpdate();

            // recalc the status after the change
            updateStatusForItem(conn, itemId);
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    // add stock by a certain amount
    public void addStock(int itemId, int amount) {
        String sql = "UPDATE inventory_items SET quantity = quantity + ? WHERE item_id = ?";
        try (Connection conn = connect();
                PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, amount);
            stmt.setInt(2, itemId);
            stmt.executeUpdate();

            // recalc the status after the change
            updateStatusForItem(conn, itemId);
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
}
