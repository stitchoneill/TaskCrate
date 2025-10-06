package source;

import javax.servlet.ServletException;
import javax.servlet.http.*;
import java.io.IOException;

public class DeleteItemServlet extends HttpServlet {

    // shared logic for deleting an item (used by both GET + POST)
    private void handle(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        int id = -1;

        // try to read the item id from the request
        try {
            id = Integer.parseInt(req.getParameter("itemId"));
        } catch (Exception ignore) {
            // if it's not a number, leave id = -1
        }

        // quick debug print (shows in server logs)
        System.out.println("DeleteItemServlet itemId=" + id);

        // only delete if we got a valid id
        if (id > 0) {
            new InventoryDAO(getServletContext()).deleteItem(id);
        }

        // decide where to send the user back (default = list.jsp)
        String returnTo = req.getParameter("returnTo");
        if (returnTo == null || returnTo.trim().isEmpty())
            returnTo = "list.jsp";

        // redirect back to that page
        resp.sendRedirect(req.getContextPath() + "/" + returnTo);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        // run the same logic on POST
        handle(req, resp);
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        // run the same logic on GET
        handle(req, resp);
    }
}
