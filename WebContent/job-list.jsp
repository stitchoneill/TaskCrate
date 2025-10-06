<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*, java.time.*, java.time.format.DateTimeFormatter, source.JobDAO, source.Job" %>
<%
    // grab all jobs then filter out ones that are finished/cancelled/deleted
    JobDAO dao = new JobDAO(application);
    List<Job> jobs = dao.getAllJobs();

    List<Job> activeJobs = new ArrayList<>();
    for (Job j : jobs) {
        String s = (j.getStatus()==null ? "" : j.getStatus().trim()).toLowerCase(Locale.ROOT);
        if (!(s.equals("completed") || s.equals("cancelled") || s.equals("deleted"))) {
            activeJobs.add(j);
        }
    }

    // some handy bits from the request + base path
    String ctx   = request.getContextPath();
    String q     = Optional.ofNullable(request.getParameter("q")).orElse("").trim();     // search box
    String when  = Optional.ofNullable(request.getParameter("when")).orElse("all");      // filter bucket
    String order = Optional.ofNullable(request.getParameter("order")).orElse("desc");    // newest/oldest

    // date helpers
    DateTimeFormatter F    = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    DateTimeFormatter DISP = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    LocalDate today = LocalDate.now();

    // quick way to put each job into a “bucket” based on date
    java.util.function.Function<Job,String> bucket = (Job j) -> {
        String d = (j.getScheduledDate()==null) ? "" : j.getScheduledDate().trim();
        if (d.isEmpty()) return "unscheduled";
        try {
            LocalDate due = LocalDate.parse(d.substring(0, Math.min(10, d.length())), F);
            if (due.isBefore(today)) return "overdue";
            if (!due.isAfter(today.plusDays(3))) return "soon";
            return "scheduled";
        } catch(Exception e) {
            return "unscheduled";
        }
    };

    // build the list we’ll actually display (search + filter applied)
    List<Job> view = new ArrayList<>();
    for (Job j : activeJobs) {
        if (!q.isEmpty()) {
            String hay = ((j.getName()==null?"":j.getName()) + " " +
                          (j.getDescription()==null?"":j.getDescription())).toLowerCase(Locale.ROOT);
            if (!hay.contains(q.toLowerCase(Locale.ROOT))) continue;
        }
        String b = bucket.apply(j);
        if (!"all".equals(when) && !b.equals(when)) continue;
        view.add(j);
    }

    // sort by id (which works as “newest/oldest” for us)
    Comparator<Job> cmp = Comparator.comparingInt(Job::getJobId);
    if ("desc".equalsIgnoreCase(order)) cmp = cmp.reversed();
    Collections.sort(view, cmp);
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">

<!-- keep the saved theme before CSS loads to avoid a flash -->
<script>
(function () {
  try {
    var t = localStorage.getItem('theme');
    if (t) document.documentElement.setAttribute('data-theme', t);
  } catch (e) {}
})();
</script>

<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Jobs</title>
<link rel="stylesheet" href="http://localhost:8080<%= ctx %>/ui-theme.css?v=<%= System.currentTimeMillis() %>">

<style>
  /* screen-reader only helper */
  .sr-only{
    position:absolute!important;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;
    clip:rect(0,0,0,0);white-space:nowrap;border:0;
  }

  :root { --row-h: 52px; --thead-h: 44px; }

  /* on phones: let the whole page scroll (nicer than pinning table) */
  .table-scroll{
    overflow: visible;
    max-height: none;
    position: relative;
    border-radius: 12px;
  }
  .jobs-table thead th{ background: var(--card, #fff); }

  /* on wider screens: cap the inner list height and keep header in view */
  @media (min-width: 901px){
    .table-scroll{
      max-height: calc(var(--thead-h) + (20 * var(--row-h)));
      overflow: auto;
    }
    .jobs-table thead th{ position: sticky; top: 0; z-index: 1; }
  }

  /* fieldset sometimes forces min-width; we don’t want that */
  fieldset { min-width: 0; }

  /* row action buttons appear only when the row is “selected” */
  .row-actions{ display:none; gap:8px; }
  tr.is-selected .row-actions{ display:inline-flex; }
  .row-actions form{ display:inline; margin:0; }

  /* modal/iframe sizing */
  #frameModal .modal-card { padding:0; }
  #frameModal .modal-body { padding:0; }
  #frameIframe {
    width:100% !important; display:block; border:0; margin:0; overflow:hidden !important;
    height:60vh; /* starting size; we resize after load */
  }

  /* compact controls up top */
  .controls-bar{ display:flex; gap:12px; flex-wrap:wrap; align-items:flex-end; margin:8px 0 12px; }
  .mini-form{ display:flex; gap:8px; align-items:flex-end; }
  .mini-form .field{ display:flex; flex-direction:column; gap:4px; }
  .mini-form input[type="search"], .mini-form select, .mini-form button{ height:36px; min-height:36px; }
</style>

<script>
  // make the list act like single-select: pick one row at a time
  function selectRow(cb){
    const rows = document.querySelectorAll('.jobs-list .job-item');
    rows.forEach(r => {
      const box = r.querySelector('input[name="jobId"]');
      if (box && box !== cb) {
        box.checked = false;
        r.classList.remove('is-selected');
      }
    });
    cb.closest('.job-item').classList.toggle('is-selected', cb.checked);
  }
</script>

</head>
<body>
<div class="container" role="main" aria-labelledby="pageTitle">
  <h1 id="pageTitle">Jobs</h1>

  <!-- toolbar: add job, search/filter, and a link back home -->
  <div class="toolbar jobs-toolbar" style="display:flex;gap:10px;margin-bottom:12px">
    <a class="btn btn-primary"
       data-modal="iframe"
       data-title="Add Job"
       href="<%= ctx %>/add-job.jsp">Add Job</a>

    <form class="toolbar-filter" method="get" action="">
      <input name="q" type="search" value="<%= q %>" placeholder="Job or description" aria-label="Search jobs">
      <select name="when" aria-label="Status filter">
        <option value="all"         <%= "all".equals(when) ? "selected":"" %>>All</option>
        <option value="unscheduled" <%= "unscheduled".equals(when) ? "selected":"" %>>Unscheduled</option>
        <option value="overdue"     <%= "overdue".equals(when) ? "selected":"" %>>Overdue</option>
        <option value="soon"        <%= "soon".equals(when) ? "selected":"" %>>Due Soon (≤3 days)</option>
        <option value="scheduled"   <%= "scheduled".equals(when) ? "selected":"" %>>Scheduled</option>
      </select>
      <select name="order" aria-label="Order">
        <option value="desc" <%= "desc".equalsIgnoreCase(order) ? "selected":"" %>>Newest first</option>
        <option value="asc"  <%= "asc".equalsIgnoreCase(order)  ? "selected":"" %>>Oldest first</option>
      </select>

      <button class="btn" type="submit">Apply</button>
      <a class="btn btn-neutral" href="<%= ctx %>/job-list.jsp">Clear</a>
    </form>

    <span style="flex:1"></span>

    <a class="btn btn-primary" href="<%= ctx %>/index.jsp">Home</a>
  </div>

  <!-- the list itself (one row per active job) -->
  <div class="list jobs-list" role="list">
  <% if (view.isEmpty()) { %>
    <div class="row"><span class="muted">No matching jobs.</span></div>
  <% } else {
       for (Job job : view) {
         String d = (job.getScheduledDate()==null) ? "" : job.getScheduledDate().trim();

         // set the little badge on the right based on the due date
         String badgeText, badgeCls;
         if (d.isEmpty()) { badgeText="Unscheduled"; badgeCls="b-blue"; }
         else {
           try {
             LocalDate due = LocalDate.parse(d.substring(0, Math.min(10, d.length())), F);
             if (due.isBefore(today))                  { badgeText="Overdue";   badgeCls="b-red";   }
             else if (!due.isAfter(today.plusDays(3))) { badgeText="Due Soon";  badgeCls="b-amber"; }
             else                                      { badgeText="Scheduled"; badgeCls="b-blue";  }
           } catch(Exception e) { badgeText="Invalid Date"; badgeCls="b-amber"; }
         }

         // show a nicer date for humans
         String prettyDate = "";
         if (!d.isEmpty()) {
           try { prettyDate = LocalDate.parse(d.substring(0, Math.min(10,d.length())), F).format(DISP); }
           catch(Exception e){ prettyDate = d.substring(0, Math.min(10,d.length())); }
         }
  %>

  <div class="row job-item" role="listitem" data-id="<%= job.getJobId() %>">
    <!-- select box (picking a row reveals the action buttons on the right) -->
    <label class="chk-wrap">
      <%
        String cbId = "sel_" + job.getJobId();
        String hintId = "selhint_" + job.getJobId();
      %>
      <input class="chk" type="checkbox" id="<%= cbId %>" name="jobId"
             value="<%= job.getJobId() %>" aria-describedby="<%= hintId %>"
             onchange="selectRow(this)">
      <span id="<%= hintId %>" class="sr-only">Selecting shows Edit, Complete and Delete buttons.</span>
    </label>

    <!-- job title + small details -->
    <div class="job-main">
      <div class="job-title"><%= job.getName() %></div>
      <div class="job-sub">
        <%= prettyDate.isEmpty() ? "" : prettyDate %>
        <%= (job.getDescription()==null || job.getDescription().isBlank()) ? "" : " — " + job.getDescription() %>
      </div>
    </div>

    <!-- status + actions (Edit opens modal, Complete archives, Delete uses hidden form) -->
    <div class="job-right">
      <span class="badge <%= badgeCls %>"><%= badgeText %></span>

      <span class="row-actions">
        <a class="btn btn-neutral btn-compact"
           data-modal="iframe"
           data-title="Edit Job"
           href="<%= ctx %>/edit-job.jsp?jobId=<%= job.getJobId() %>">Edit</a>

        <form method="post" action="<%= ctx %>/EditJobServlet">
          <input type="hidden" name="jobId" value="<%= job.getJobId() %>">
          <input type="hidden" name="status" value="Completed">
          <input type="hidden" name="archive" value="1">
          <button class="btn btn-green btn-compact"
                  onclick="return confirm('Mark this job as Completed?');">
            Complete
          </button>
        </form>

        <button type="button" class="btn btn-red btn-compact"
                onclick="rowDelete(<%= job.getJobId() %>)">
          Delete
        </button>
      </span>
    </div>
  </div>

  <% } } %>
</div>

  <!-- this form is used by the Delete buttons (we just set the id and submit it) -->
  <form id="deleteForm" method="post" action="<%= ctx %>/DeleteSelectedJobsServlet" style="display:none;">
    <input type="hidden" name="jobId" value="">
  </form>
</div>

<!-- reusable iframe modal for add/edit -->
<div id="frameModal" class="modal" role="dialog" aria-modal="true" aria-labelledby="frameTitle">
  <div class="modal-card" style="width:1060px;max-width:calc(100% - 32px);">
    <div class="modal-header">
      <h2 id="frameTitle">Add Job</h2>
      <button id="frameClose" class="modal-close" type="button" aria-label="Close">&times;</button>
    </div>
    <div class="modal-body">
      <iframe id="frameIframe" title="Add or Edit Job"></iframe>
    </div>
  </div>
</div>

<script>
(function(){
  // modal + iframe wiring (so “Add Job” and “Edit” open inside a dialog)
  const modal  = document.getElementById('frameModal');
  const iframe = document.getElementById('frameIframe');
  const title  = document.getElementById('frameTitle');
  const closeB = document.getElementById('frameClose');

  function openFrame(url, label){
    title.textContent = label || 'Add Job';
    modal.setAttribute('open','');
    document.body.classList.add('no-scroll');
    const src = url + (url.indexOf('?')>-1 ? '&' : '?') + 'embed=1';
    iframe.src = src;
  }
  function closeFrame(){
    modal.removeAttribute('open');
    document.body.classList.remove('no-scroll');
    iframe.src = 'about:blank';
  }
  window.closeFrame = closeFrame; // used by child pages

  // any link with data-modal="iframe" will pop the modal
  document.querySelectorAll('a[data-modal="iframe"]').forEach(a=>{
    a.addEventListener('click', (e)=>{
      e.preventDefault();
      openFrame(a.getAttribute('href'), a.dataset.title || a.textContent.trim());
    });
  });

  // once the inner page loads, tidy it up and fit the height
  iframe.addEventListener("load", () => {
    try {
      const href = iframe.contentWindow.location.href;

      // if the inner page navigates back to job-list/index, close and refresh
      if ((/job-list\.jsp/i.test(href) && href.includes("added=1")) ||
          /\/(job-list|index)\.jsp(\?|$)/i.test(href)) {
        closeFrame();
        location.reload();
        return;
      }

      const doc = iframe.contentDocument || iframe.contentWindow.document;
      if (doc && doc.body) {
        doc.documentElement.style.margin = "0";
        doc.body.style.margin = "0";
        doc.body.style.overflow = "hidden";
      }

      // try to pull a nicer title from inside
      let childTitle = null;
      const tNode = doc.querySelector('[data-title]');
      if (tNode && tNode.getAttribute('data-title')) {
        childTitle = tNode.getAttribute('data-title').trim();
      } else {
        const h = doc.querySelector('h1,h2,h3');
        if (h) childTitle = h.textContent.trim();
      }
      if (childTitle) title.textContent = childTitle;

      // if the inner page already shows the same title, hide the duplicate
      const firstHeading = doc.querySelector('h1,h2,h3');
      if (firstHeading && firstHeading.textContent.trim() === title.textContent.trim()) {
        firstHeading.style.display = 'none';
      }

      // resize the iframe to fit its content (with a cap)
      const fit = () => {
        const b = doc.body, html = doc.documentElement;
        const contentH = Math.max(b.scrollHeight, html.scrollHeight, b.offsetHeight, html.offsetHeight);
        const maxH = Math.floor(window.innerHeight * 0.85);
        iframe.style.height = Math.min(contentH, maxH) + 'px';
      };
      fit();
      new MutationObserver(fit).observe(doc.body, {subtree:true, childList:true, attributes:true, characterData:true});
      window.addEventListener('resize', fit);

    } catch(e) { /* ignore cross-origin issues */ }
  });

  // close actions
  closeB.addEventListener('click', closeFrame);
  modal.addEventListener('click', (e)=>{ if (e.target === modal) closeFrame(); });
  document.addEventListener('keydown', (e)=>{ if (e.key === 'Escape' && modal.hasAttribute('open')) closeFrame(); });

  // helper for the “Delete” button on each row
  window.rowDelete = function(jobId){
    if (!confirm('Delete this job? This cannot be undone.')) return;
    const form = document.getElementById('deleteForm');
    form.querySelector('input[name="jobId"]').value = String(jobId);
    form.submit();
  };

  // also used by inner pages to close modal then refresh
  window.closeModalAndReload = function(){ closeFrame(); location.reload(); };
})();
</script>
</body>
</html>
