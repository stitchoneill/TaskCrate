// Servlet that handles the "Add Job" form: collects details, picks items + quantities, saves, then redirects
package source;

import javax.servlet.ServletException;
import javax.servlet.http.*;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

public class AddJobServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        // make sure form text comes through correctly
        request.setCharacterEncoding("UTF-8");

        // basic job details from the form
        String jobName = n(request.getParameter("jobName"));
        String description = n(request.getParameter("jobDesc"));
        String scheduledDate = n(request.getParameter("scheduledDate"));
        String status = n(request.getParameter("status"));

        // if no status was chosen, treat it as "Planned"
        if (status.isEmpty()) {
            status = "Planned"; 
        }

        // build up the list of items that were ticked/selected for this job
        List<JobItem> jobItems = new ArrayList<>();
        String[] selectedItemIds = request.getParameterValues("itemId");

        if (selectedItemIds != null) {
            for (String idStr : selectedItemIds) {
                // convert item id safely; skip anything dodgy
                int itemId = p(idStr, -1);
                if (itemId <= 0)
                    continue;

                // quantity can come under two possible names (covers both cases)
                String q1 = request.getParameter("qty_" + itemId);
                String q2 = request.getParameter("quantity_" + itemId);
                int qty = p(q1, p(q2, 0)); // try qty_, if that fails try quantity_, otherwise 0

                // only add the item if there’s actually a positive quantity
                if (qty > 0) {
                    jobItems.add(new JobItem(0, itemId, qty));
                }
            }
        }

        // save the job + its items via the DAO
        JobDAO dao = new JobDAO(getServletContext());
        dao.addJob(jobName, description, scheduledDate, status, jobItems);

        // where to go after saving (fall back to job-list.jsp)
        String returnTo = request.getParameter("returnTo");
        if (returnTo == null || returnTo.isBlank()) {
            returnTo = "job-list.jsp";
        }

        // send the user back to the list with a little "added=1" flag
        // (note: this ignores returnTo and always goes to job-list.jsp)
        response.sendRedirect(request.getContextPath() + "/job-list.jsp?added=1");

    }

    // safe int parse with a default if it's missing or invalid
    private static int p(String s, int def) {
        try {
            return Integer.parseInt(s);
        } catch (Exception e) {
            return def;
        }
    }

    // never return null; trim spaces so the values are clean
    private static String n(String s) {
        return (s == null) ? "" : s.trim();
    }
}
