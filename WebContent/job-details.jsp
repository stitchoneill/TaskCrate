<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*, source.JobDAO, source.JobItem, source.Job, source.InventoryDAO, source.InventoryItem" %>
<%
    int jobId = -1;
    try { jobId = Integer.parseInt(request.getParameter("jobId")); } catch(Exception ignore){}
    boolean history = "1".equals(request.getParameter("history")) || "true".equalsIgnoreCase(request.getParameter("history"));
    boolean embed   = "1".equals(request.getParameter("embed"))   || "true".equalsIgnoreCase(request.getParameter("embed"));

    JobDAO jdao = new JobDAO(application);
    Job job = null;

    if (!history) {
        job = jdao.getJobById(jobId);
    } else {
        for (Job j : jdao.getHistoryJobs()) {
            if (j.getJobId() == jobId) { job = j; break; }
        }
    }

    List<JobItem> items = history ? jdao.getHistoryJobItems(jobId) : jdao.getJobItems(jobId);

    InventoryDAO invDao = new InventoryDAO(application);
    Map<Integer, InventoryItem> invMap = new HashMap<>();
    for (InventoryItem it : invDao.getAllItems()) invMap.put(it.getItemId(), it);

    String ctx = request.getContextPath();

    if (job == null) {
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Job not found</title>
<script>
(function () {
  try {
    var t = localStorage.getItem('theme');
    if (t) document.documentElement.setAttribute('data-theme', t);
  } catch (e) {}
})();
</script>
<link rel="stylesheet" href="http://localhost:8080<%= ctx %>/ui-theme.css?v=<%= System.currentTimeMillis() %>">
<style>
  html,body{margin:0;padding:0;background:transparent;}
</style>
</head>
<body class="<%= embed ? "embed" : "" %>">
  <div class="container">
    <div class="card">
      <h2>Job not found</h2>
      <div class="muted">This job no longer exists.</div>
    </div>
  </div>
</body>
</html>
<%  return; } %>

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Job #<%= job.getJobId() %> — <%= job.getName()==null?"":job.getName() %></title>
<link rel="stylesheet" href="http://localhost:8080<%= ctx %>/ui-theme.css?v=<%= System.currentTimeMillis() %>">
<style>
  html,body{margin:0;padding:0;background:transparent;}
  body.embed .container{max-width:none;padding:20px;}
  body.embed .card{background:transparent;border:0;box-shadow:none;padding:0;}
  body.embed .dup-title{display:none;}

  /* fix bold labels clipping */
  .kv b{
    display:inline-block;
    line-height:1.35;
    padding-top:1px;
    vertical-align:middle;
  }
  .kv > div{
    line-height:1.35;
  }
</style>
</head>
<body class="<%= embed ? "embed" : "" %>">

<span data-title="Job #<%= job.getJobId() %> — <%= job.getName()==null?"":job.getName() %>" hidden></span>

<div class="container">
  <h2 class="dup-title">Job #<%= job.getJobId() %> — <%= job.getName()==null?"":job.getName() %></h2>

  <div class="card" style="display:flex;flex-direction:column;gap:12px;">
    <!-- summary -->
    <div class="kv" style="display:grid;grid-template-columns:1fr 1fr;gap:10px;font-size:14px;">
      <div><b>Scheduled:</b> <%= job.getScheduledDate()==null? "" : job.getScheduledDate() %></div>
      <div><b>Status:</b> <%= job.getStatus()==null? "" : job.getStatus() %></div>
    </div>

    <!-- description -->
    <div>
      <b style="display:block;margin-bottom:6px;">Description</b>
      <div style="padding:8px;background:#fafafa;border:1px solid #eee;border-radius:8px;">
        <%= job.getDescription()==null? "" : job.getDescription() %>
      </div>
    </div>

    <!-- items used -->
    <div>
      <b>Items used</b>
      <div class="list" style="border:1px solid var(--border);border-radius:10px;overflow:hidden;background:#fafbfc;margin-top:6px;">
        <table>
          <thead>
            <tr>
              <th>Item</th>
              <th style="width:120px;">Qty Used</th>
            </tr>
          </thead>
          <tbody>
          <%
            if (items == null || items.isEmpty()) {
          %>
            <tr><td colspan="2" class="muted" style="padding:10px;">No items recorded.</td></tr>
          <%
            } else {
              for (JobItem ji : items) {
                InventoryItem it = invMap.get(ji.getItemId());
                String nm = (it==null) ? ("Item #" + ji.getItemId()) : it.getName();
          %>
            <tr>
              <td><%= nm %></td>
              <td><%= ji.getQuantityUsed() %></td>
            </tr>
          <%  } } %>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>

<script>
(function(){
  const isEmbed = /(?:^|[?&])embed=(?:1|true)\b/i.test(location.search);
  if (!isEmbed) return;
  try {
    const span = document.querySelector('[data-title]');
    if (span && window.parent && window.parent.document) {
      const t = span.getAttribute('data-title');
      const el = window.parent.document.getElementById('frameTitle');
      if (el && t) el.textContent = t;
      document.title = t || document.title;
    }
  } catch(e) {}
})();
</script>
</body>
</html>
