<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*, source.InventoryDAO, source.InventoryItem" %>
<%
    // base path for links/forms
    String ctx  = request.getContextPath();

    // get everything from the DB
    InventoryDAO dao  = new InventoryDAO(application);
    List<InventoryItem> items = dao.getAllItems();

    // filters from the URL (with defaults)
    String qs    = Optional.ofNullable(request.getParameter("q")).orElse("").trim();        // search text
    String stock = Optional.ofNullable(request.getParameter("stock")).orElse("all").trim(); // all / out / low / in
    String order = Optional.ofNullable(request.getParameter("order")).orElse("desc").trim();// newest/oldest

    // decide which “bucket” an item is in based on qty and its threshold
    java.util.function.Function<InventoryItem,String> bucket = (InventoryItem it) -> {
        int qv = it.getQuantity();
        int th = it.getLowStockThreshold();
        if (qv <= 0) return "out";
        if (qv <= th) return "low";
        return "in";
    };

    // build the list we’ll actually show (search + filter applied)
    List<InventoryItem> view = new ArrayList<>();
    for (InventoryItem it : items) {
        if (!qs.isEmpty()) {
            String hay = ((it.getName()==null?"":it.getName()) + " " +
                          (it.getDescription()==null?"":it.getDescription()))
                         .toLowerCase(Locale.ROOT);
            if (!hay.contains(qs.toLowerCase(Locale.ROOT))) continue;
        }
        String b = bucket.apply(it);
        if (!"all".equals(stock) && !b.equals(stock)) continue;
        view.add(it);
    }

    // sort by id so “newest first” works like expected
    Comparator<InventoryItem> cmp = Comparator.comparingInt(InventoryItem::getItemId);
    if ("desc".equalsIgnoreCase(order)) cmp = cmp.reversed();
    Collections.sort(view, cmp);
%>

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">

<!-- set saved theme ASAP so there’s no flash -->
<script>
(function () {
  try {
    var t = localStorage.getItem('theme');
    if (t) document.documentElement.setAttribute('data-theme', t);
  } catch (e) {}
})();
</script>

<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Inventory</title>
<link rel="stylesheet" href="http://localhost:8080<%= ctx %>/ui-theme.css?v=<%= System.currentTimeMillis() %>">

<style>
  /* helpers */
  .sr-only{position:absolute!important;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0;}
  .row-actions{display:none;gap:8px}
  tr.is-selected .row-actions{display:inline-flex}

  /* modal/iframe sizing */
  #frameModal .modal-card{padding:0;width:560px;max-width:calc(100% - 32px);max-height:85vh;}
  #frameModal .modal-body{ padding:0; }
  #frameIframe{width:100% !important;display:block;border:0;margin:0;overflow:hidden !important;height:360px;}
</style>

<script>
  // pick one row at a time (tick one, untick the rest)
  function selectRow(cb){
    const rows = document.querySelectorAll('.inv-list .inv-item');
    rows.forEach(r => {
      const box = r.querySelector('input[name="itemId"]');
      if (box && box !== cb) { box.checked = false; r.classList.remove('is-selected'); }
    });
    cb.closest('.inv-item').classList.toggle('is-selected', cb.checked);
  }

  // open the iframe modal (used for add/edit/delete screens)
  function openFrame(url, label){
    const modal  = document.getElementById('frameModal');
    const iframe = document.getElementById('frameIframe');
    const title  = document.getElementById('frameTitle');

    if (title) title.textContent = label || 'Modal';
    modal.setAttribute('open','');
    document.body.classList.add('no-scroll');
    iframe.style.height = '360px';

    const src = url + (url.indexOf('?')>-1 ? '&' : '?') + 'embed=1';
    iframe.src = src;
  }

  // close the modal and clear the iframe
  function closeFrame(){
    const modal  = document.getElementById('frameModal');
    const iframe = document.getElementById('frameIframe');
    modal.removeAttribute('open');
    document.body.classList.remove('no-scroll');
    iframe.src = 'about:blank';
  }

  // clicking outside or pressing ESC closes the modal
  document.addEventListener('click', (e) => {
    const m = document.getElementById('frameModal');
    if (e.target === m) closeFrame();
  });
  document.addEventListener('keydown', (e) => {
    const m = document.getElementById('frameModal');
    if (e.key === 'Escape' && m.hasAttribute('open')) closeFrame();
  });

  // when the inner page loads, grab a nicer title and auto-fit height
  window.addEventListener('load', () => {
    const iframe = document.getElementById('frameIframe');

    iframe.addEventListener('load', () => {
      try {
        const href = iframe.contentWindow.location.href;

        // if inner page returns to list.jsp, close and refresh
        if (/\/list\.jsp(\?|$)/i.test(href)) { closeFrame(); location.reload(); return; }

        const doc = iframe.contentDocument || iframe.contentWindow.document;

        // prefer a [data-title] from the child, otherwise first heading
        const tNode = doc.querySelector('[data-title]');
        const titleEl = document.getElementById('frameTitle');
        if (titleEl) {
          if (tNode && tNode.getAttribute('data-title')) titleEl.textContent = tNode.getAttribute('data-title');
          else {
            const h = doc.querySelector('h1,h2,h3');
            if (h) titleEl.textContent = h.textContent.trim();
          }
        }

        // make the inner page seamless
        doc.documentElement.style.margin = '0';
        doc.body.style.margin = '0';
        doc.body.style.overflow = 'hidden';

        // resize the iframe to fit its content (capped)
        const resize = () => {
          const body = doc.body, html = doc.documentElement;
          const contentH = Math.max(body.scrollHeight, html.scrollHeight, body.offsetHeight, html.offsetHeight);
          const maxH = Math.floor(window.innerHeight * 0.85);
          iframe.style.height = Math.min(contentH, maxH) + 'px';
        };

        resize();
        new MutationObserver(resize).observe(doc.body, {subtree:true, childList:true, attributes:true, characterData:true});
        window.addEventListener('resize', resize);
      } catch(e) { /* ignore any cross-origin oddities */ }
    });
  });

  // turn links/buttons with data-modal="iframe" into modal openers
  document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('a[data-modal="iframe"], button[data-modal="iframe"]').forEach(el => {
      el.addEventListener('click', (e) => {
        e.preventDefault();
        const url   = el.getAttribute('href') || el.dataset.href || '#';
        const title = el.dataset.title || el.textContent.trim() || 'Modal';
        openFrame(url, title);
      });
    });
  });
</script>
</head>
<body>
<div class="container" role="main" aria-labelledby="pageTitle">
  <h1 id="pageTitle">Inventory</h1>

  <!-- top bar: add item, search/filter, and a link home -->
  <div class="toolbar jobs-toolbar" style="display:flex;gap:10px;margin-bottom:12px">
    <a class="btn btn-primary"
       data-modal="iframe"
       data-title="Add Item"
       href="<%= ctx %>/add-item.jsp">Add Item</a>

    <form class="toolbar-filter" method="get" action="">
      <input name="q" type="search" value="<%= qs %>" placeholder="Item or description" aria-label="Search items">
      <select name="stock" aria-label="Stock filter">
        <option value="all" <%= "all".equals(stock) ? "selected":"" %>>All</option>
        <option value="out" <%= "out".equals(stock) ? "selected":"" %>>Out of Stock</option>
        <option value="low" <%= "low".equals(stock) ? "selected":"" %>>Low Stock (≤2)</option>
        <option value="in"  <%= "in".equals(stock)  ? "selected":"" %>>In Stock</option>
      </select>
      <select name="order" aria-label="Order">
        <option value="desc" <%= "desc".equalsIgnoreCase(order) ? "selected":"" %>>Newest first</option>
        <option value="asc"  <%= "asc".equalsIgnoreCase(order)  ? "selected":"" %>>Oldest first</option>
      </select>
      <button class="btn" type="submit">Apply</button>
      <a class="btn btn-neutral" href="<%= request.getRequestURI() %>">Clear</a>
    </form>

    <span style="flex:1"></span>
    <a class="btn btn-neutral" href="<%= ctx %>/index.jsp">Home</a>
  </div>

  <!-- the list of items (one row each) -->
  <div class="list inv-list" role="list">
  <% if (view == null || view.isEmpty()) { %>
    <div class="row"><span class="muted">No matching items.</span></div>
  <% } else {
       for (InventoryItem it : view) {
         int qty = it.getQuantity();
         int th  = it.getLowStockThreshold();
         if (th <= 0) th = 2; // belt-and-braces default

         String label, badgeCls;
         if (qty <= 0) {
             label = "Out of Stock"; badgeCls = "b-red";
         } else if (qty <= th) {
             label = "Low Stock";    badgeCls = "b-amber";
         } else {
             label = "In Stock";     badgeCls = "b-green";
         }
  %>

    <div class="row inv-item" role="listitem" data-id="<%= it.getItemId() %>">
      <!-- select box (shows the action buttons on the right) -->
      <label class="chk-wrap">
        <%
          String cbId   = "itemchk_" + it.getItemId();
          String hintId = "itemhint_" + it.getItemId();
        %>
        <input class="chk" type="checkbox" id="<%= cbId %>" name="itemId"
               value="<%= it.getItemId() %>" aria-describedby="<%= hintId %>"
               onchange="selectRow(this)">
        <span id="<%= hintId %>" class="sr-only">Selecting shows Edit and Delete.</span>
      </label>

      <!-- name + small details -->
      <div class="job-main">
        <div class="job-title"><%= it.getName() %></div>
        <div class="job-sub">
          Qty: <%= qty %>
          <%= (it.getDescription()==null || it.getDescription().isBlank())
                ? "" : " &ndash; " + it.getDescription() %>
        </div>
      </div>

      <!-- badge + edit/delete (only visible when selected) -->
      <div class="job-right">
        <span class="badge <%= badgeCls %>"><%= label %></span>

        <span class="row-actions">
  <a class="btn btn-neutral btn-compact"
     data-modal="iframe"
     data-title="Edit Item"
     href="<%= ctx %>/edit-item.jsp?itemId=<%= it.getItemId() %>">Edit</a>

  <button class="btn btn-red btn-compact" type="button"
          onclick="if(confirm('Delete this item?')) window.location = '<%= ctx %>/DeleteItemServlet?itemId=<%= it.getItemId() %>&returnTo=list.jsp'">
    Delete
  </button>
</span>
      </div>
    </div>

  <% } } %>
  </div>

  <!-- reusable iframe modal -->
  <div id="frameModal" class="modal" role="dialog" aria-modal="true" aria-labelledby="frameTitle">
    <div class="modal-card">
      <div class="modal-header">
        <h2 id="frameTitle">Modal</h2>
        <button id="frameClose" class="modal-close" type="button" aria-label="Close" onclick="closeFrame()">
          <span aria-hidden="true">&times;</span>
        </button>
      </div>

      <div class="modal-body">
        <iframe id="frameIframe" title="Modal content"></iframe>
      </div>
    </div>
  </div>
</div>
</body>
</html>
