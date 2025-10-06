package source;

import javax.servlet.ServletException;
import javax.servlet.http.*;
import java.io.IOException;
import java.util.Arrays;

public class DeleteSelectedServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        // DAO for talking to the inventory table
        InventoryDAO dao = new InventoryDAO(getServletContext());

        // get all the selected item ids from the checkboxes
        String[] ids = req.getParameterValues("itemId");
        System.out.println("DBG-bulk-delete itemId[] = " + Arrays.toString(ids));

        // loop through and try to delete each one
        if (ids != null) {
            for (String s : ids) {
                try {
                    int id = Integer.parseInt(s);
                    System.out.println("DBG-bulk-delete deleting " + id);
                    dao.deleteItem(id);
                } catch (NumberFormatException bad) {
                    // if something slips in that isn't a number, just log it
                    System.out.println("DBG-bulk-delete NOT a number: " + s);
                } catch (Exception ex) {
                    // any other issue while deleting gets logged here
                    System.out.println("DBG-bulk-delete Error id " + s);
                    ex.printStackTrace();
                }
            }
        }

        // send the user back to where they were (default to list.jsp)
        String returnTo = req.getParameter("returnTo");
        if (returnTo == null || returnTo.trim().isEmpty())
            returnTo = "list.jsp";
        resp.sendRedirect(req.getContextPath() + "/" + returnTo);
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        // allow GET to do the same thing (useful if the form submits via GET)
        doPost(req, resp);
    }
}
