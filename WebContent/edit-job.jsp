<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*, source.JobDAO, source.Job, source.InventoryDAO, source.InventoryItem, source.JobItem" %>
<%
    // base path for links/forms
    String ctx = request.getContextPath();

    // these are passed in from the servlet when it forwards here
    Job job = (Job) request.getAttribute("job");
    List<InventoryItem> items = (List<InventoryItem>) request.getAttribute("inventory");
    Map<Integer,Integer> usedMap = (Map<Integer,Integer>) request.getAttribute("usedMap");

    // if we landed here without attributes (e.g. direct link), try to load from the id in the URL
    if (job == null) {
        String idStr = request.getParameter("jobId");
        if (idStr != null && !idStr.isEmpty()) {
            JobDAO jdao = new JobDAO(application);
            int jid = Integer.parseInt(idStr);

            job = jdao.getJobById(jid);

            // build a quick map of itemId -> qty already used on this job
            usedMap = new HashMap<>();
            for (JobItem ji : jdao.getJobItems(jid)) {
                usedMap.put(ji.getItemId(), ji.getQuantityUsed());
            }
        }
    }

    // if we still don’t have inventory, fetch it
    if (items == null) items = new InventoryDAO(application).getAllItems();
%>
<% if (job == null) { %>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">

  <!-- keep theme consistent before CSS loads -->
  <script>
(function () {
  try {
    var t = localStorage.getItem('theme');
    if (t) document.documentElement.setAttribute('data-theme', t);
  } catch (e) {}
})();
</script>

  <!-- main stylesheet (cache-busted so changes show) -->
  <link rel="stylesheet" href="http://localhost:8080<%= ctx %>/ui-theme.css?v=<%= System.currentTimeMillis() %>">
  <base target="_top">
  <style>
    /* keep the modal clean */
    html,body{margin:0;padding:0;background:transparent;overflow:hidden;}
  </style>
</head>
<body class="container">
  <!-- simple fallback if the id is bad/missing -->
  <h3>Couldn’t load job.</h3>
  <a class="btn" href="<%= ctx %>/job-list.jsp">Back to Jobs</a>
</body>
</html>
<% return; } %>

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Edit Job</title>

<!-- site styles -->
<link rel="stylesheet" href="http://localhost:8080<%= ctx %>/ui-theme.css?v=<%= System.currentTimeMillis() %>">
<base target="_top">
<style>
  /* make the iframe/modal look seamless */
  html,body{margin:0;padding:0;background:transparent;overflow:hidden;}
  .form-basic{max-width:none !important;width:100% !important;margin:0 !important;box-sizing:border-box;}
</style>
<script>
  // enable/disable qty box based on checkbox
  function toggleQty(checkbox, itemId) {
    const qtyBox = document.getElementById('quantity_' + itemId);
    qtyBox.disabled = !checkbox.checked;
    if (!checkbox.checked) qtyBox.value = '';
  }
  // confirm then submit the hidden delete form
  function deleteJob(){
    if(!confirm('Delete this job? This cannot be undone.')) return;
    document.getElementById('deleteForm').submit();
  }
</script>
</head>
<body>

<!-- parent modal reads this for the title bar -->
<span data-title="Edit Job — <%= (job.getName()==null ? "Untitled" : job.getName()) %>" hidden></span>

<!-- main edit form -->
<form method="post" action="<%= ctx %>/EditJobServlet" target="_top">
  <!-- carry the job id, and flag that items were posted so servlet knows to process them -->
  <input type="hidden" name="jobId" value="<%= job.getJobId() %>">
  <input type="hidden" name="itemsPosted" value="1">
  <input type="hidden" name="status" value="<%= job.getStatus()==null? "Planned" : job.getStatus() %>">

  <div class="form-basic" style="padding:20px">
    <!-- basic details -->
    <label for="jobName">Job Name</label>
    <input type="text" name="jobName" id="jobName" required
           value="<%= job.getName()==null? "" : job.getName() %>">

    <label for="jobDesc">Description</label>
    <input type="text" name="jobDesc" id="jobDesc"
           value="<%= job.getDescription()==null? "" : job.getDescription() %>">

    <label for="scheduledDate">Scheduled Date</label>
    <input type="date" name="scheduledDate" id="scheduledDate"
           value="<%= job.getScheduledDate()==null ? "" : (job.getScheduledDate().length()>=10 ? job.getScheduledDate().substring(0,10) : job.getScheduledDate()) %>">

    <!-- pick items + quantities -->
    <h2 style="margin-top:20px">Select Items for Job</h2>
    <div class="item-table-container">
      <table>
        <thead>
          <tr>
            <th>Select</th>
            <th>Item</th>
            <th>Currently Used</th>
            <th>Qty to Use</th>
          </tr>
        </thead>
        <tbody>
<%
   if (usedMap == null) usedMap = new HashMap<>();
   for (InventoryItem it : items) {
       int id    = it.getItemId();
       int stock = it.getQuantity();
       Integer used = usedMap.get(id);
       boolean checked = (used != null && used > 0);

       // while editing we let them increase up to (stock + already-used)
       int effectiveMax = stock + (checked ? used : 0);
%>
  <tr>
    <td>
      <input type="checkbox" name="itemId" value="<%= id %>"
             onclick="toggleQty(this, '<%= id %>')"
             <%= checked ? "checked" : "" %>
             <%= (!checked && stock==0) ? "disabled" : "" %>>
    </td>

    <td>
      <%= it.getName() %>
      <small class="muted">( <%= stock %> in stock )</small>
    </td>

    <!-- NEW: shows how many are currently used on this job -->
    <td class="muted" style="text-align:center;">
      <%= (used == null ? 0 : used) %>
    </td>

    <td>
      <input class="qty" type="number" id="quantity_<%= id %>"
             name="qty_<%= id %>"
             min="1"
             <%= (effectiveMax > 0 ? "max=\"" + effectiveMax + "\"" : "") %>
             <%= checked ? "" : "disabled" %>
             value="<%= checked ? used : "" %>">
    </td>
  </tr>
<% } %>
</tbody>
      </table>
    </div>

    <!-- actions: save, delete, or cancel -->
    <div class="actions" style="margin-top:16px;justify-content:flex-start">
      <button class="btn btn-primary" type="submit">Save Changes</button>
      <button class="btn btn-danger" type="button"
              aria-label="Delete job <%= (job.getName()==null ? "" : job.getName()) %>"
              onclick="deleteJob()">Delete Job</button>
      <button type="button" class="btn btn-neutral" onclick="window.parent.closeFrame()">Cancel</button>
    </div>
  </div>
</form>

<!-- hidden form used by the Delete button above -->
<form id="deleteForm" method="post" action="<%= ctx %>/DeleteJobServlet?jobId=<%= job.getJobId() %>" style="display:none;"></form>
</body>
</html>
