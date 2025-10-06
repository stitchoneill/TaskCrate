<%@ page language="java" contentType="text/html; charset=UTF-8"
pageEncoding="UTF-8" %> <%@ page import="java.util.*, source.InventoryDAO,
source.InventoryItem" %> <% String ctx = request.getContextPath(); InventoryDAO
invDao = new InventoryDAO(application); List<InventoryItem>
  items = invDao.getAllItems(); %>
  <!DOCTYPE html>
  <html lang="en">
    <head>
      <meta charset="UTF-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>Add Job</title>

      <!-- keep the chosen theme before CSS loads (stops a flash) -->
      <script>
(function () {
  try {
    var t = localStorage.getItem('theme');
    if (t) document.documentElement.setAttribute('data-theme', t);
  } catch (e) {}
})();
</script>

      <!-- main stylesheet (cache-busted so updates show right away) -->
      <link
        rel="stylesheet"
        href="http://localhost:8080<%= ctx %>/ui-theme.css?v=<%= System.currentTimeMillis() %>"
      />
      <base target="_top" />
      <script>
        // enable/disable the qty box when a row is ticked/unticked
        function toggleQty(checkbox, itemId) {
          const qtyBox = document.getElementById("quantity_" + itemId);
          qtyBox.disabled = !checkbox.checked;
          if (!checkbox.checked) qtyBox.value = "";
        }
      </script>
    </head>
    <body>
      <!-- add-job form: details at the top, pick items below -->
      <form method="post" action="<%= ctx %>/AddJobServlet" target="_top">
        <div class="form-basic" style="padding: 20px">
          <!-- basic job fields -->
          <label for="jobName">Job Name</label>
          <input type="text" name="jobName" id="jobName" required />

          <label for="jobDesc">Description</label>
          <input type="text" name="jobDesc" id="jobDesc" />

          <label for="scheduledDate">Scheduled Date</label>
          <input type="date" name="scheduledDate" id="scheduledDate" />

          <!-- pick which items the job will use + how many -->
          <h2 style="margin-top: 20px">Select Items for Job</h2>
          <div class="item-table-container">
            <table>
              <thead>
                <tr>
                  <th>Select</th>
                  <th>Item</th>
                  <th>Qty to Use</th>
                </tr>
              </thead>
              <tbody>
                <% for (InventoryItem it : items) { %>
                <tr>
                  <td>
                    <!-- if no stock, checkbox is disabled -->
                    <input type="checkbox" name="itemId" value="<%=
                    it.getItemId() %>" onclick="toggleQty(this, '<%=
                    it.getItemId() %>')" <%= it.getQuantity()==0 ? "disabled" :
                    "" %>>
                  </td>
                  <td>
                    <!-- show name + current stock so it's clear what’s available -->
                    <%= it.getName() %>
                    <small class="muted"
                      >( <%= it.getQuantity() %> in stock )</small
                    >
                  </td>
                  <td>
                    <!-- qty box stays disabled until the row is ticked -->
                    <input
                      class="qty"
                      type="number"
                      id="quantity_<%= it.getItemId() %>"
                      name="quantity_<%= it.getItemId() %>"
                      min="1"
                      max="<%= it.getQuantity() %>"
                      disabled
                    />
                  </td>
                </tr>
                <% } %>
              </tbody>
            </table>
          </div>

          <!-- actions: create job or go back to the list -->
          <div
            class="actions"
            style="margin-top: 16px; justify-content: flex-start"
          >
            <button class="btn btn-primary" type="submit">Create Job</button>
            <a
              class="btn btn-secondary"
              href="<%= ctx %>/job-list.jsp"
              target="_top"
              >Back to Jobs</a
            >
          </div>
        </div>
      </form>
    </body>
</html>
