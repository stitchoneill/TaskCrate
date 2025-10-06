package source;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.sql.SQLException;

public class CompleteJobServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        // get the job id from the form/button
        String id = req.getParameter("jobId");

        // only try to complete if we actually got an id
        if (id != null && !id.isEmpty()) {
            try {
                int jobId = Integer.parseInt(id);

                // mark the job as completed + archive it
                JobDAO dao = new JobDAO(getServletContext());
                dao.archiveJob(jobId, "Completed", false);

            } catch (NumberFormatException e) {
                // if jobId wasn't a number, just log it for now
                e.printStackTrace();
            } catch (SQLException e) {
                // DB problem — log the error (kept simple)
                e.printStackTrace();
            }
        }

        // go back to the job list either way
        resp.sendRedirect(req.getContextPath() + "/job-list.jsp");
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        // allow GET to behave the same as POST for this action
        doPost(req, resp);
    }
}
