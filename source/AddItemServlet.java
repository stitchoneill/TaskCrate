/** Servlet for adding items to the inventory */
package source;

import javax.servlet.ServletException;
import javax.servlet.http.*;
import java.io.IOException;

public class AddItemServlet extends HttpServlet {
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        // make sure any text from the form (names, descriptions) is read as UTF-8
        request.setCharacterEncoding("UTF-8");

        // get the form values (use helpers so we don't crash on null/blank)
        String name = n(request.getParameter("name"));
        String description = n(request.getParameter("description"));
        int quantity = pInt(request.getParameter("quantity"), 0);   // default to 0 if not valid
        int threshold = pInt(request.getParameter("threshold"), 2); // default to 2 if not valid

        // work out the stock status from the numbers above
        String status;
        if (quantity == 0)
            status = "out_of_stock";
        else if (quantity <= threshold)
            status = "low_stock";
        else
            status = "in_stock";

        // build the item with everything we collected/calculated
        InventoryItem item = new InventoryItem();
        item.setName(name);
        item.setDescription(description);
        item.setQuantity(quantity);
        item.setStatus(status);
        item.setLowStockThreshold(threshold);   

        // save it using the DAO (DB code lives in there)
        new InventoryDAO(getServletContext()).addItem(item);

        // decide where to send the user next (fallback to list.jsp)
        String returnTo = request.getParameter("returnTo");
        if (returnTo == null || returnTo.isEmpty())
            returnTo = "list.jsp";
        response.sendRedirect(request.getContextPath() + "/" + returnTo);
    }

    // try to turn a string into an int; if it fails, just use the default
    private static int pInt(String s, int d) {
        try { return Integer.parseInt(s); }
        catch (Exception e) { return d; }
    }

    // never return null strings; trim spaces so inputs are tidy
    private static String n(String s) {
        return s == null ? "" : s.trim();
    }
}
