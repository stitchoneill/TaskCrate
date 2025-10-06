package source;

import javax.servlet.ServletException;
import javax.servlet.http.*;
import javax.servlet.ServletContext;
import java.io.IOException;
import java.util.*;

public class EditJobServlet extends HttpServlet {

    private static final String JOBS_PAGE = "/job-list.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        // grab the job id from the link/button
        String idParam = req.getParameter("jobId");
        System.out.println("EditJobServlet GET jobId param = " + idParam);

        // if there’s no id, just go back to the list
        if (idParam == null) {
            resp.sendRedirect(req.getContextPath() + JOBS_PAGE);
            return;
        }

        // make sure the id is actually a number
        int jobId;
        try {
            jobId = Integer.parseInt(idParam);
        } catch (NumberFormatException e) {
            System.out.println("EditJobServlet: jobId not a number: " + idParam);
            resp.sendRedirect(req.getContextPath() + JOBS_PAGE);
            return;
        }

        // fetch the job + inventory so we can show the edit screen
        ServletContext ctx = getServletContext();
        JobDAO jobDao = new JobDAO(ctx);
        Job job = jobDao.getJobById(jobId);
        System.out.println("EditJobServlet: dao.getJobById(" + jobId + ") -> " + (job != null));

        // if the job doesn’t exist, go back to the list
        if (job == null) {
            resp.sendRedirect(req.getContextPath() + JOBS_PAGE);
            return;
        }

        InventoryDAO invDao = new InventoryDAO(ctx);
        List<InventoryItem> inventory = invDao.getAllItems();

        // get the items already used on this job and map them by itemId -> qty
        List<JobItem> existing = jobDao.getJobItems(jobId);
        Map<Integer, Integer> usedMap = new HashMap<>();
        for (JobItem ji : existing)
            usedMap.put(ji.getItemId(), ji.getQuantityUsed());

        // attach everything to the request for the JSP to render
        req.setAttribute("job", job);
        req.setAttribute("inventory", inventory);
        req.setAttribute("usedMap", usedMap);

        // show the edit page
        req.getRequestDispatcher("/edit-job.jsp").forward(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        // keep accents/emoji etc. intact
        req.setCharacterEncoding("UTF-8");

        // job id must be valid or we’re done
        int jobId;
        try {
            jobId = Integer.parseInt(req.getParameter("jobId"));
        } catch (Exception e) {
            resp.sendRedirect(req.getContextPath() + JOBS_PAGE);
            return;
        }

        // make sure the job actually exists (in case someone edited the URL)
        JobDAO jobDao = new JobDAO(getServletContext());
        Job existing = jobDao.getJobById(jobId);
        if (existing == null) {
            resp.sendRedirect(req.getContextPath() + JOBS_PAGE);
            return;
        }

        // keep posted values if provided, otherwise stick with what we already had
        String name = keepOr(req.getParameter("jobName"), existing.getName());
        String desc = keepOr(req.getParameter("jobDesc"), existing.getDescription());
        String date = keepOr(req.getParameter("scheduledDate"), existing.getScheduledDate());
        String status = keepOr(req.getParameter("status"), existing.getStatus());

        // these flags come from hidden inputs / form controls
        boolean archive = "1".equals(req.getParameter("archive")) ||
                "true".equalsIgnoreCase(req.getParameter("archive"));

        boolean itemsPosted = "1".equals(req.getParameter("itemsPosted")) ||
                req.getParameterValues("itemId") != null;

        try {
            // if the user wants to archive the job (complete/cancel/delete etc.)
            if (archive) {
                // only update the text fields if something was actually posted
                boolean postedAnyEdit = (req.getParameter("jobName") != null) ||
                        (req.getParameter("jobDesc") != null) ||
                        (req.getParameter("scheduledDate") != null);

                if (postedAnyEdit) {
                    jobDao.updateJob(jobId, safe(name), safe(desc), safe(date), safe(status));
                }

                // if status is deleted/cancelled we’ll put stock back
                boolean restock = false;
                String s = status == null ? "" : status.trim().toLowerCase(Locale.ROOT);
                if ("deleted".equals(s) || "cancelled".equals(s))
                    restock = true;

                // if nothing was set, treat it as completed
                if (s.isEmpty()) {
                    status = "Completed";
                } 

                // archive the job with the chosen status
                jobDao.archiveJob(jobId, status, restock);

                // back to the list when done
                resp.sendRedirect(req.getContextPath() + JOBS_PAGE);
                return;
            }

            // normal edit flow: save basic details
            jobDao.updateJob(jobId, safe(name), safe(desc), safe(date), safe(status));

            // if items were posted, rebuild the list of job items
            if (itemsPosted) {
                String[] selectedIds = req.getParameterValues("itemId");
                List<JobItem> newItems = new ArrayList<>();
                if (selectedIds != null) {
                    for (String sId : selectedIds) {
                        try {
                            int itemId = Integer.parseInt(sId);

                            // qty might come under two different parameter names
                            String q = coalesce(req.getParameter("qty_" + itemId),
                                    req.getParameter("quantity_" + itemId));
                            int qty = parseInt(q);

                            // only keep positive quantities
                            if (qty > 0) {
                                JobItem ji = new JobItem();
                                ji.setJobId(jobId);
                                ji.setItemId(itemId);
                                ji.setQuantityUsed(qty);
                                newItems.add(ji);
                            }
                        } catch (NumberFormatException ignore) {
                            // skip anything that isn’t a number
                        }
                    }
                }
                // replace the old items with the new list in one go
                jobDao.replaceJobItems(jobId, newItems);
            }

            // done editing — back to the list
            resp.sendRedirect(req.getContextPath() + JOBS_PAGE);

        } catch (Exception e) {
            // simple error handling for now (good enough for demo/EMA)
            e.printStackTrace();
            resp.sendError(500, "Failed to update/archive job: " + e.getMessage());
        }
    }

    // if the posted value is empty, keep the old one
    private static String keepOr(String posted, String fallback) {
        return (posted == null || posted.trim().isEmpty()) ? fallback : posted.trim();
    }

    // trim and avoid nulls
    private static String safe(String s) {
        return s == null ? "" : s.trim();
    }

    // first non-null wins
    private static String coalesce(String a, String b) {
        return (a != null) ? a : b;
    }

    // parse int safely; default to 0 if bad
    private static int parseInt(String s) {
        try {
            return Integer.parseInt(s);
        } catch (Exception e) {
            return 0;
        }
    }
}
