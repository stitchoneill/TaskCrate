<%@ page language="java" contentType="text/html; charset=UTF-8"
pageEncoding="UTF-8" %> <% String ctx = request.getContextPath(); %>
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Add Item</title>
    
    <!-- remember the chosen theme before CSS loads so there’s no flash -->
    <script>
(function () {
  try {
    var t = localStorage.getItem('theme');
    if (t) document.documentElement.setAttribute('data-theme', t);
  } catch (e) {}
})();
</script>

    <!-- pull in the main UI styles (cache-busted so changes show immediately) -->
    <link
      rel="stylesheet"
      href="http://localhost:8080<%= ctx %>/ui-theme.css?v=<%= System.currentTimeMillis() %>"
    />
    <base target="_top" />
    <style>
      /* keep the iframe/page clean and full width */
      html,
      body {
        margin: 0;
        padding: 0;
        background: transparent;
        overflow: hidden;
      }
      /* form stretches to the container, no weird margins */
      form.seamless-form {
        padding: 20px;
        max-width: none;
        width: 100%;
        margin: 0;
        box-sizing: border-box;
      }
    </style>
  </head>
  <body>

    <!-- this hidden span is used by the parent frame to show a title -->
    <span data-title="Add Item" hidden></span>

    <!-- main add-item form -->
    <form
      class="seamless-form"
      method="post"
      action="<%= ctx %>/AddItemServlet"
    >
      <!-- item name (required) -->
      <div class="rowf">
        <label for="a_name">Name</label>
        <input id="a_name" name="name" type="text" required />
      </div>

      <!-- short description (optional) -->
      <div class="rowf">
        <label for="a_desc">Description</label>
        <input id="a_desc" name="description" type="text" />
      </div>

      <!-- how many we have in stock right now -->
      <div class="rowf">
        <label for="a_qty">Quantity</label>
        <input
          id="a_qty"
          name="quantity"
          type="number"
          value="0"
          min="0"
          required
        />
      </div>

      <!-- when to warn as “low stock” (default 2 to match backend) -->
      <div class="rowf">
        <label for="a_threshold">Stock Level Warning (threshold)</label>
        <input
          id="a_threshold"
          name="threshold"
          type="number"
          value="2"
          min="0"
        />
      </div>

      <!-- where to go after saving (the servlet reads this) -->
      <input type="hidden" name="returnTo" value="list.jsp" />

      <!-- actions: cancel closes the iframe, submit saves -->
      <div class="actions" style="justify-content: flex-start">
        <button
          type="button"
          class="btn btn-neutral"
          onclick="window.parent.closeFrame()"
        >
          Cancel
        </button>
        <button type="submit" class="btn btn-primary">Add Item</button>
      </div>
    </form>
  </body>
</html>
