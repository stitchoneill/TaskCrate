package source;

import javax.servlet.ServletException;
import javax.servlet.http.*;
import java.io.IOException;
import java.sql.SQLException;

public class DeleteJobServlet extends HttpServlet {

  @Override
  protected void doPost(HttpServletRequest req, HttpServletResponse resp)
      throws ServletException, IOException {

    // get the job id from the request
    String id = req.getParameter("jobId");

    // only try if something was passed in
    if (id != null && !id.isEmpty()) {
      try {
        int jobId = Integer.parseInt(id);

        // tell the DAO to archive this job as "Deleted"
        JobDAO dao = new JobDAO(getServletContext());
        dao.archiveJob(jobId, "Deleted", true);

      } catch (NumberFormatException | SQLException e) {
        // log the error (bad number or database problem)
        e.printStackTrace();
      }
    }

    // always go back to the job list afterwards
    resp.sendRedirect(req.getContextPath() + "/job-list.jsp");
  }

  @Override
  protected void doGet(HttpServletRequest req, HttpServletResponse resp)
      throws ServletException, IOException {
    // allow GET to work the same as POST
    doPost(req, resp);
  }
}
