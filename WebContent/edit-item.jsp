<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="source.InventoryDAO, source.InventoryItem, java.util.Optional" %>
<%
  // keep inputs readable (accents/emojis etc.)
  request.setCharacterEncoding("UTF-8");

  // handy base path for links/forms
  String ctx = request.getContextPath();

  // where to go back to after saving/cancel (default list.jsp)
  String returnTo = Optional.ofNullable(request.getParameter("returnTo")).orElse("list.jsp");

  // read the id we want to edit
  int itemId = -1;
  try { itemId = Integer.parseInt(request.getParameter("itemId")); } catch (Exception ignore) {}

  // load the item
  InventoryDAO dao = new InventoryDAO(application);
  InventoryItem item = (itemId > 0) ? dao.getItemById(itemId) : null;

  // if we can’t find it, show a simple “not found” page and stop
  if (item == null) {
%>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Item not found</title>

  <!-- keep theme consistent before CSS loads -->
  <script>
(function () {
  try {
    var t = localStorage.getItem('theme');
    if (t) document.documentElement.setAttribute('data-theme', t);
  } catch (e) {}
})();
</script>

  <!-- main stylesheet (cache-busted so updates show up) -->
  <link rel="stylesheet" href="http://localhost:8080<%= ctx %>/ui-theme.css?v=<%= System.currentTimeMillis() %>">
  <base target="_top">
  <style>html,body{margin:0;padding:0;background:transparent}</style>
</head>
<body>
  <div class="embed-shell">
    <div class="card">
      <h2>Item not found</h2>
      <p class="muted">The requested item does not exist.</p>
      <div class="actions" style="justify-content:flex-start">
        <a class="btn btn-primary" href="<%= ctx %>/list.jsp" target="_top">Back to Inventory</a>
      </div>
    </div>
  </div>
</body>
</html>
<%
    return; // stop here, nothing else to render
  }

  // make sure the threshold we show has a sensible default
  int thVal = item.getLowStockThreshold();
  if (thVal <= 0) thVal = 2; // safety default
%>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Edit Item</title>

  <!-- main stylesheet (cache-busted so edits are visible) -->
  <link rel="stylesheet" href="http://localhost:8080<%= ctx %>/ui-theme.css?v=<%= System.currentTimeMillis() %>">
  <base target="_top">
  <style>
    /* keep the iframe page clean and fixed size */
    html,body{margin:0;padding:0;background:transparent;overflow:hidden}
    /* let the form stretch nicely inside the modal */
    .form-basic{padding:20px;max-width:none;width:100%;box-sizing:border-box;margin:0}
  </style>
</head>
<body>
  <!-- parent modal reads this for the title bar -->
  <span data-title="Edit Item — <%= (item.getName()==null ? "Untitled" : item.getName()) %>" hidden></span>

  <!-- edit form (posts back to servlet) -->
  <form method="post" action="<%= ctx %>/EditItemServlet" target="_top">
    <!-- carry the id + where to return afterwards -->
    <input type="hidden" name="itemId"   value="<%= item.getItemId() %>">
    <input type="hidden" name="returnTo" value="<%= returnTo %>">

    <div class="form-basic card" style="box-shadow:none;border:0;background:transparent;padding-top:0">
      <!-- name -->
      <label for="name">Name</label>
      <input id="name" name="name" type="text" value="<%= Optional.ofNullable(item.getName()).orElse("") %>" required>

      <!-- description -->
      <label for="description">Description</label>
      <input id="description" name="description" type="text" value="<%= Optional.ofNullable(item.getDescription()).orElse("") %>">

      <!-- quantity -->
      <label for="quantity">Quantity</label>
      <input id="quantity" name="quantity" type="number" min="0" value="<%= item.getQuantity() %>" required>

      <!-- low stock threshold -->
      <label for="threshold">Stock Level Warning (threshold)</label>
      <input id="threshold" name="threshold" type="number" min="0" value="<%= thVal %>" required>

      <!-- actions: cancel closes modal (fallback: go back), save updates -->
      <div class="actions" style="margin-top:16px;justify-content:flex-start">
        <button type="button" class="btn btn-neutral" onclick="try{window.parent.closeFrame()}catch(_){window.location.href='<%= ctx %>/<%= returnTo %>'}">Cancel</button>
        <button class="btn btn-primary" type="submit">Update Item</button>
      </div>
    </div>
  </form>
</body>
</html>
