package source;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class DeleteSelectedJobsServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        // quick log of what came in (helps for debugging)
        System.out.println(
                "DeleteSelectedJobsServlet: values=" +
                        Arrays.toString(req.getParameterValues("jobId")) +
                        ", single=" + req.getParameter("jobId"));

        // get all selected job ids (could be multiple checkboxes or just one value)
        String[] idParams = req.getParameterValues("jobId");

        // if nothing came through as an array, fall back to a single value
        if ((idParams == null || idParams.length == 0) && req.getParameter("jobId") != null) {
            idParams = new String[] { req.getParameter("jobId") };
        }

        // collect ids into a list of integers
        List<Integer> ids = new ArrayList<>();
        if (idParams != null) {
            for (String s : idParams) {
                try {
                    ids.add(Integer.parseInt(s));
                } catch (Exception ignore) {
                    // skip anything that isn't a number
                }
            }
        }

        // log which ones we’re actually going to delete
        System.out.println("DeleteSelectedJobsServlet: toDelete=" + ids);

        // if we have any valid ids, ask the DAO to mark them as deleted
        if (!ids.isEmpty()) {
            JobDAO dao = new JobDAO(getServletContext());
            try {
                dao.archiveJobs(ids, "Deleted", true);
            } catch (SQLException e) {
                // log any DB error
                e.printStackTrace();
            }
        }

        // go back to the job list afterwards
        resp.sendRedirect(req.getContextPath() + "/job-list.jsp");
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        // allow GET requests to work the same way
        doPost(req, resp);
    }
}
