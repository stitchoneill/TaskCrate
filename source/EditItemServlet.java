package source;

import javax.servlet.ServletException;
import javax.servlet.http.*;
import java.io.IOException;

public class EditItemServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        // read text properly (handles special characters)
        request.setCharacterEncoding("UTF-8");

        // grab values from the edit form
        int itemId    = parseInt(request.getParameter("itemId"), -1);
        String name   = n(request.getParameter("name"));
        String desc   = n(request.getParameter("description"));
        int quantity  = parseInt(request.getParameter("quantity"), 0);
        int threshold = parseInt(request.getParameter("threshold"), 2);

        // work out the stock status from quantity vs threshold
        String status;
        if (quantity == 0) {
            status = "out_of_stock";
        } else if (quantity <= threshold) {
            status = "low_stock";
        } else {
            status = "in_stock";
        }

        // only try to save if we have a valid item id
        if (itemId > 0) {
            // build the item with updated details
            InventoryItem item = new InventoryItem();
            item.setItemId(itemId);
            item.setName(name);
            item.setDescription(desc);
            item.setQuantity(quantity);
            item.setStatus(status);
            item.setLowStockThreshold(threshold);   // keep the low-stock setting with the item

            // update the item in the database
            InventoryDAO dao = new InventoryDAO(getServletContext());
            dao.updateItem(item);                   // also persists threshold + status
        }

        // send the user back to where they came from (default to index.jsp)
        String returnTo = request.getParameter("returnTo");
        if (returnTo == null || returnTo.trim().isEmpty()) {
            returnTo = "index.jsp";
        }
        response.sendRedirect(request.getContextPath() + "/" + returnTo);
    }

    // safe int parse with a default if it isn't a number
    private static int parseInt(String s, int def) {
        try {
            return Integer.parseInt(s);
        } catch (Exception e) {
            return def;
        }
    }

    // never return null; trim spaces so inputs are tidy
    private static String n(String s) {
        return (s == null) ? "" : s.trim();
    }
}
