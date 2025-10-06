<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*, java.time.*, java.time.format.DateTimeFormatter,
                 source.InventoryDAO, source.InventoryItem,
                 source.JobDAO, source.Job, source.JobItem" %>
<%
    // base path for links
    String ctx = request.getContextPath();

    // pull all inventory and split into low / out of stock lists
    InventoryDAO invDao = new InventoryDAO(application);
    List<InventoryItem> allItems = invDao.getAllItems();
    List<InventoryItem> lowStock = new ArrayList<>();
    List<InventoryItem> outStock = new ArrayList<>();

    for (InventoryItem it : allItems) {
        String st = it.getStatus();
        if ("out_of_stock".equals(st)) {
            outStock.add(it);
        } else if ("low_stock".equals(st)) {
            lowStock.add(it);
        }
    }

    // jobs: current and history
    JobDAO jobDao = new JobDAO(application);
    List<Job> currentJobs = jobDao.getActiveJobs();
    List<Job> historyJobs = jobDao.getHistoryJobs();

    // date helpers
    DateTimeFormatter F    = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    DateTimeFormatter DISP = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    LocalDate today = LocalDate.now();

    // current jobs: order + search
    String cjDir    = Optional.ofNullable(request.getParameter("cjdir")).orElse("asc");
    String cjSearch = Optional.ofNullable(request.getParameter("cjsearch")).orElse("").trim();

    // simple text filter on name/description
    List<Job> currentFiltered = new ArrayList<>();
    for (Job j : currentJobs) {
        if (cjSearch.isEmpty()) { currentFiltered.add(j); continue; }
        String hay = ((j.getName()==null?"":j.getName()) + " " +
                      (j.getDescription()==null?"":j.getDescription())).toLowerCase();
        if (hay.contains(cjSearch.toLowerCase())) currentFiltered.add(j);
    }

    // sort current jobs into buckets: overdue / due soon / scheduled / no date
    Comparator<Job> byStatus = Comparator.comparingInt((Job j) -> {
        String d = (j.getScheduledDate()==null ? "" : j.getScheduledDate());
        try {
            if (d.length() >= 10) {
                LocalDate due = LocalDate.parse(d.substring(0,10), F);
                if (due.isBefore(today)) return 0;                  // overdue
                else if (!due.isAfter(today.plusDays(3))) return 1; // due soon
                else return 2;                                      // scheduled
            }
        } catch(Exception ignore){}
        return 3;                                                   // unscheduled/invalid
    });
    Comparator<Job> cjComp = "desc".equalsIgnoreCase(cjDir) ? byStatus.reversed() : byStatus;
    Collections.sort(currentFiltered, cjComp);

    // history panel: filters + search + sort
    String histFilter = Optional.ofNullable(request.getParameter("hfilter")).orElse("all");
    String histDir    = Optional.ofNullable(request.getParameter("hdir")).orElse("desc");
    String hSearch    = Optional.ofNullable(request.getParameter("hsearch")).orElse("").trim();

    List<Job> historyDisplay = new ArrayList<>();
    for (Job j : historyJobs) {
        String st = (j.getStatus()==null) ? "" : j.getStatus();
        if ("completed".equalsIgnoreCase(histFilter) && !"Completed".equalsIgnoreCase(st)) continue;
        if ("deleted".equalsIgnoreCase(histFilter)   && !"Deleted".equalsIgnoreCase(st))   continue;
        if ("cancelled".equalsIgnoreCase(histFilter) && !"Cancelled".equalsIgnoreCase(st)) continue;

        if (!hSearch.isEmpty()) {
            String hay = ((j.getName()==null?"":j.getName()) + " " +
                          (j.getDescription()==null?"":j.getDescription())).toLowerCase();
            if (!hay.contains(hSearch.toLowerCase())) continue;
        }
        historyDisplay.add(j);
    }

    // sort history by scheduled date (fallback MIN)
    Comparator<Job> histByDate = Comparator.comparing((Job j) -> {
        String d = (j.getScheduledDate()==null ? "" : j.getScheduledDate());
        try { if (d.length() >= 10) return LocalDate.parse(d.substring(0,10), F); }
        catch(Exception ignore){}
        return LocalDate.MIN;
    });
    if ("desc".equalsIgnoreCase(histDir)) histByDate = histByDate.reversed();
    Collections.sort(historyDisplay, histByDate);
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>TaskCrate</title>
<link rel="stylesheet" href="http://localhost:8080<%= ctx %>/ui-theme.css?v=<%= System.currentTimeMillis() %>">

<style>
  /* modal sizing so the iframe fits neatly */
  #frameModal .modal-card { 
    padding:0;
    width:560px;                      
    max-width:calc(100% - 32px);
    max-height:85vh;
  }
  #frameModal .modal-body { padding:0; }
  #frameIframe {
    width:100% !important;
    display:block;
    border:0;
    margin:0;
    overflow:hidden !important;
    height:360px; /* starter height; JS resizes it after load */ 
  }
</style>

<script>
// ---------- iframe modal helpers (open/close + resize) ----------

function openFrame(url, label){
  const modal  = document.getElementById('frameModal');
  const iframe = document.getElementById('frameIframe');
  const title  = document.getElementById('frameTitle');

  if (title) title.textContent = label || 'Modal';
  modal.setAttribute('open','');
  document.body.classList.add('no-scroll');

  // start small; we’ll auto-fit after load
  iframe.style.height = '360px';

  // force embed=1 so inner pages know they’re in a modal
  const src = url + (url.indexOf('?')>-1 ? '&' : '?') + 'embed=1';
  iframe.src = src;
}
function closeFrame(){
  const modal  = document.getElementById('frameModal');
  const iframe = document.getElementById('frameIframe');
  modal.removeAttribute('open');
  document.body.classList.remove('no-scroll');
  iframe.src = 'about:blank';
}

// close if you click outside or press ESC
document.addEventListener('click', (e) => {
  const m = document.getElementById('frameModal');
  if (e.target === m) closeFrame();
});
document.addEventListener('keydown', (e) => {
  const m = document.getElementById('frameModal');
  if (e.key === 'Escape' && m.hasAttribute('open')) closeFrame();
});

// turn any [data-modal="iframe"] link into an iframe modal opener
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('[data-modal="iframe"]').forEach(el => {
    el.addEventListener('click', (e) => {
      e.preventDefault();
      const url   = el.getAttribute('href') || el.dataset.href || '#';
      const title = el.dataset.title || el.textContent.trim() || 'Modal';
      openFrame(url, title);
    });
  });
});

// auto-fit iframe to its content (and close on redirect back to list/index)
window.addEventListener('load', () => {
  const iframe = document.getElementById('frameIframe');
  if (!iframe) return;

  iframe.addEventListener('load', () => {
    try {
      const href = iframe.contentWindow.location.href;

      // if inner page navigates to list/index, close and refresh
      if (/\/(list|index)\.jsp(\?|$)/i.test(href)) {
        closeFrame();
        location.reload();
        return;
      }

      const doc = iframe.contentDocument || iframe.contentWindow.document;

      // grab a nicer title from the inner page if it provides one
      const tNode = doc.querySelector('[data-title]');
      const frameTitle = document.getElementById('frameTitle');
      if (frameTitle) {
        if (tNode && tNode.getAttribute('data-title')) {
          frameTitle.textContent = tNode.getAttribute('data-title').trim();
        } else {
          const h = doc.querySelector('h1,h2,h3');
          if (h) frameTitle.textContent = h.textContent.trim();
        }
      }

      // remove default margins/scrollbars inside the iframe for a clean look
      doc.documentElement.style.margin = '0';
      doc.body.style.margin = '0';
      doc.body.style.overflow = 'hidden';

      // measure and fit the iframe height (with a cap)
      const resize = () => {
        const b = doc.body, html = doc.documentElement;
        const contentH = Math.max(
          b.scrollHeight, html.scrollHeight,
          b.offsetHeight, html.offsetHeight
        );
        const maxH = Math.floor(window.innerHeight * 0.85);
        iframe.style.height = Math.min(contentH, maxH) + 'px';
      };

      resize();
      new MutationObserver(resize).observe(doc.body, { subtree:true, childList:true, attributes:true, characterData:true });
      window.addEventListener('resize', resize);

    } catch(e) {
      // ignore cross-origin errors just in case
    }
  });
});

// list select helper (keeps it single-select like radio buttons)
function selectListRow(cb){
  const list = cb.closest('.list');
  list.querySelectorAll('input[type="checkbox"]').forEach(box=>{
    if (box !== cb) { box.checked = false; box.closest('.row').classList.remove('is-selected'); }
  });
  cb.closest('.row').classList.toggle('is-selected', cb.checked);
}
</script>

</head>
<body>
<header class="app-header container" role="banner">
  <h1 class="app-title">TaskCrate</h1>
  <nav class="topbar" aria-label="Primary">
    <a class="btn btn-primary" href="<%= ctx %>/job-list.jsp">Jobs</a>
    <a class="btn" href="<%= ctx %>/list.jsp">Inventory</a>
  </nav>
</header>

<main id="main" class="container" role="main">
  <div class="grid" role="region" aria-label="Overview panels">

    <!-- ---------------- Current Jobs ---------------- -->
    <section class="card" aria-labelledby="currentJobsTitle">
      <h2 id="currentJobsTitle">Current Jobs</h2>

      <!-- small filter/search bar for current jobs -->
      <div class="controls-bar">
        <form class="mini-form" method="get" action="">
          <div class="field">
            <label for="cjdir">Order</label>
            <select id="cjdir" name="cjdir">
              <option value="asc"  <%= !"desc".equalsIgnoreCase(cjDir) ? "selected":"" %>>Ascending</option>
              <option value="desc" <%=  "desc".equalsIgnoreCase(cjDir) ? "selected":"" %>>Descending</option>
            </select>
          </div>
          <input type="hidden" name="cjsearch" value="<%= cjSearch %>">
          <button class="btn btn-compact btn-primary" type="submit">Apply</button>
        </form>

        <form class="mini-form" method="get" action="">
          <div class="field">
            <label for="cjsearch">Search</label>
            <input id="cjsearch" name="cjsearch" type="search"
                   value="<%= cjSearch %>" placeholder="Job or description">
          </div>
          <input type="hidden" name="cjdir" value="<%= cjDir %>">
          <button class="btn btn-compact btn-primary" type="submit">Search</button>
          <a class="btn btn-compact btn-gray" href="<%= ctx %>/index.jsp?cjdir=<%= cjDir %>">Clear</a>
        </form>
      </div>

      <!-- list of current jobs with simple badges -->
      <div class="list" style="max-height:320px;">
  <%
    for (Job j : currentFiltered) {
      String d = j.getScheduledDate()==null ? "" : j.getScheduledDate();
      String badgeText="Unscheduled"; String badgeCls="b-blue";
      try {
        if (!d.isEmpty()) {
          LocalDate due = (d.length()>=10) ? LocalDate.parse(d.substring(0,10), F) : null;
          if (due!=null && due.isBefore(today))                  { badgeText="Overdue";  badgeCls="b-red";   }
          else if (due!=null && !due.isAfter(today.plusDays(3))) { badgeText="Due Soon"; badgeCls="b-amber";}
          else if (due!=null)                                    { badgeText="Scheduled";badgeCls="b-blue"; }
        }
      } catch(Exception e){ badgeText="Invalid Date"; }
  %>
  <div class="row">
    <div>
      <div class="name"><%= j.getName() %></div>
      <div class="muted">
        <%
          // show date nicely (dd/MM/yyyy) if we can parse it
          String disp = "";
          if (d != null && d.length() >= 10) {
            try { disp = LocalDate.parse(d.substring(0,10), F).format(DISP); }
            catch (Exception ignore) { disp = d; }
          } else { disp = (d==null?"":d); }
          out.print(disp);
        %>
      </div>
    </div>
    <div>
      <span class="badge <%= badgeCls %>"><%= badgeText %></span>
    </div>
  </div>
  <% } %>
  <% if (currentFiltered.isEmpty()) { %>
    <div class="row"><span class="muted">No current jobs.</span></div>
  <% } %>
</div>

    </section>

    <!-- ---------------- Low Stock ---------------- -->
    <section class="card" aria-labelledby="lowStockTitle">
  <h2 id="lowStockTitle">Low Stock</h2>
  <div id="lowList" class="list job-list" role="list">
    <% if (lowStock.isEmpty()) { %>
      <div class="row"><span class="muted">No low-stock items.</span></div>
    <% } else { for (InventoryItem it : lowStock) { %>
      <div class="row inv-item" role="listitem" data-id="<%= it.getItemId() %>">
        <!-- single-select row like jobs list -->
        <label class="chk-wrap" style="display:flex;align-items:center;">
          <input type="checkbox" onchange="selectListRow(this)">
          <span class="sr-only">Select <%= it.getName() %></span>
        </label>

        <div class="job-main">
          <div class="job-title"><%= it.getName() %></div>
          <div class="job-sub"><%= Math.max(0,it.getQuantity()) %> left<%= 
            (it.getDescription()==null||it.getDescription().isBlank())?"":" — "+it.getDescription() %></div>
        </div>

        <div class="job-right">
          <span class="badge b-amber">Low</span>
          <span class="row-actions">
            <a class="btn btn-neutral btn-compact"
               data-modal="iframe"
               data-title="Edit Item"
               href="<%= ctx %>/edit-item.jsp?itemId=<%= it.getItemId() %>">Edit</a>
            <a class="btn btn-red btn-compact"
               data-modal="iframe"
               data-title="Delete Item"
               href="<%= ctx %>/delete-item.jsp?itemId=<%= it.getItemId() %>">Delete</a>
          </span>
        </div>
      </div>
    <% } } %>
  </div>
</section>

    <!-- ---------------- Job History ---------------- -->
    <section class="card" aria-labelledby="historyTitle">
      <h2 id="historyTitle">Job History</h2>

      <!-- filter/search for history -->
      <div class="controls-bar">
        <form class="mini-form" method="get" action="">
          <div class="field">
            <label for="hfilter">Filter</label>
            <select id="hfilter" name="hfilter">
              <option value="all"       <%= "all".equalsIgnoreCase(histFilter) ? "selected":"" %>>All</option>
              <option value="completed" <%= "completed".equalsIgnoreCase(histFilter) ? "selected":"" %>>Completed</option>
              <option value="deleted"   <%= "deleted".equalsIgnoreCase(histFilter)   ? "selected":"" %>>Deleted</option>
              <option value="cancelled" <%= "cancelled".equalsIgnoreCase(histFilter) ? "selected":"" %>>Cancelled</option>
            </select>
          </div>
          <div class="field">
            <label for="hdir">Order</label>
            <select id="hdir" name="hdir">
              <option value="desc" <%= !"asc".equalsIgnoreCase(histDir) ? "selected":"" %>>Newest</option>
              <option value="asc"  <%=  "asc".equalsIgnoreCase(histDir) ? "selected":"" %>>Oldest</option>
            </select>
          </div>
          <input type="hidden" name="hsearch" value="<%= hSearch %>">
          <button class="btn btn-compact btn-primary" type="submit">Apply</button>
        </form>

        <form class="mini-form" method="get" action="">
          <div class="field">
            <label for="hsearch">Search</label>
            <input id="hsearch" name="hsearch" type="search"
                   value="<%= hSearch %>" placeholder="Job or description">
          </div>
          <input type="hidden" name="hfilter" value="<%= histFilter %>">
          <input type="hidden" name="hdir" value="<%= histDir %>">
          <button class="btn btn-compact btn-primary" type="submit">Search</button>
          <a class="btn btn-compact btn-gray" href="<%= ctx %>/index.jsp?hfilter=<%= histFilter %>&hdir=<%= histDir %>">Clear</a>
        </form>
      </div>

      <!-- list of archived jobs -->
      <div class="list" style="max-height:280px;">
        <% for (Job j : historyDisplay) { %>
        <div class="row">
          <div>
            <div class="name"><%= j.getName() %></div>
            <div class="muted"><%
              String d = (j.getScheduledDate()==null?"":j.getScheduledDate());
              if (d.length()>=10) {
                try { out.print(LocalDate.parse(d.substring(0,10), F).format(DISP)); }
                catch(Exception e){ out.print(d.substring(0, Math.min(10,d.length()))); }
              } else { out.print(d); }
            %></div>
          </div>
          <!-- open details in the iframe modal -->
          <button class="btn btn-compact btn-neutral"
        data-modal="iframe"
        data-title="Job Details"
        data-href="<%= ctx %>/job-details.jsp?history=1&jobId=<%= j.getJobId() %>"
        type="button"
        aria-label="View details for <%= j.getName() %>">
  View
</button>
        </div>
        <% } %>
        <% if (historyDisplay.isEmpty()) { %>
        <div class="row"><span class="muted">No history yet.</span></div>
        <% } %>
      </div>
    </section>

    <!-- ---------------- Out of Stock ---------------- -->
    <section class="card" aria-labelledby="outStockTitle">
  <h2 id="outStockTitle">Out of Stock</h2>
  <div id="outList" class="list job-list" role="list">
    <% if (outStock.isEmpty()) { %>
      <div class="row"><span class="muted">Nothing is out of stock.</span></div>
    <% } else { for (InventoryItem it : outStock) { %>
      <div class="row inv-item" role="listitem" data-id="<%= it.getItemId() %>">
        <label class="chk-wrap" style="display:flex;align-items:center;">
          <input type="checkbox" onchange="selectListRow(this)">
          <span class="sr-only">Select <%= it.getName() %></span>
        </label>

        <div class="job-main">
          <div class="job-title"><%= it.getName() %></div>
          <div class="job-sub"><%= (it.getDescription()==null||it.getDescription().isBlank())?"":" — "+it.getDescription() %></div>
        </div>

        <div class="job-right">
          <span class="badge b-red">Out of Stock</span>
          <span class="row-actions">
            <a class="btn btn-neutral btn-compact"
               data-modal="iframe"
               data-title="Edit Item"
               href="<%= ctx %>/edit-item.jsp?itemId=<%= it.getItemId() %>">Edit</a>
            <a class="btn btn-red btn-compact"
               data-modal="iframe"
               data-title="Delete Item"
               href="<%= ctx %>/delete-item.jsp?itemId=<%= it.getItemId() %>">Delete</a>
          </span>
        </div>
      </div>
    <% } } %>
  </div>
</section>

  </div>
</main>

<footer class="container" role="contentinfo" style="margin-top:16px;">
  <p class="muted">© <%= LocalDate.now().getYear() %> InventoryApp</p>
</footer>

<!-- ------------- Reusable iframe modal ------------- -->
<div id="frameModal" class="modal" role="dialog" aria-modal="true" aria-labelledby="frameTitle">
  <div class="modal-card">
    <div class="modal-header">
      <h3 id="frameTitle">Modal</h3>
      <button id="frameClose" class="modal-close" type="button" aria-label="Close" onclick="closeFrame()">
        <span aria-hidden="true">&times;</span>
      </button>
    </div>
    <div class="modal-body">
      <iframe id="frameIframe" title="Modal content"></iframe>
    </div>
  </div>
</div>

<script>
// duplicate modal helpers (kept here so this file works standalone on refresh)

function openFrame(url, label){
  const modal  = document.getElementById('frameModal');
  const iframe = document.getElementById('frameIframe');
  const title  = document.getElementById('frameTitle');

  title && (title.textContent = label || 'Modal');
  modal.setAttribute('open','');
  document.body.classList.add('no-scroll');

  // start tiny; we’ll resize after load
  iframe.style.height = '1px';

  const src = url + (url.indexOf('?')>-1 ? '&' : '?') + 'embed=1';
  iframe.src = src;
}
function closeFrame(){
  const modal  = document.getElementById('frameModal');
  const iframe = document.getElementById('frameIframe');
  modal.removeAttribute('open');
  document.body.classList.remove('no-scroll');
  iframe.src = 'about:blank';
}

// basic close handlers
document.addEventListener('click', (e) => {
  const m = document.getElementById('frameModal');
  if (e.target === m) closeFrame();
});
document.addEventListener('keydown', (e) => {
  const m = document.getElementById('frameModal');
  if (e.key === 'Escape' && m.hasAttribute('open')) closeFrame();
});

// wire up [data-modal="iframe"] links
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('[data-modal="iframe"]').forEach(el => {
    el.addEventListener('click', (e) => {
      e.preventDefault();
      const url   = el.getAttribute('href') || el.dataset.href || '#';
      const title = el.dataset.title || el.textContent.trim() || 'Modal';
      openFrame(url, title);
    });
  });
});

// resize the iframe to fit its content
window.addEventListener('load', () => {
  const iframe = document.getElementById('frameIframe');
  if (!iframe) return;

  iframe.addEventListener('load', () => {
    try {
      const href = iframe.contentWindow.location.href;

      // if inner page navigates back to list/index, close and refresh parent
      if (/\/(list|index)\.jsp(\?|$)/i.test(href)) {
        closeFrame();
        location.reload();
        return;
      }

      const doc = iframe.contentDocument || iframe.contentWindow.document;

      // use child-provided title if present
      const tNode = doc.querySelector('[data-title]');
      const title = document.getElementById('frameTitle');
      if (title) {
        title.textContent = tNode?.getAttribute('data-title')?.trim()
          || (doc.querySelector('h1,h2,h3')?.textContent?.trim() || title.textContent);
      }

      // tidy up inner page spacing/scroll
      doc.documentElement.style.margin = '0';
      doc.body.style.margin = '0';
      doc.body.style.overflow = 'hidden';

      // measure the important bit and fit height (capped)
      const fit = () => {
        const core = doc.querySelector('.embed-shell, .form-basic, form') || doc.body;
        const rect = core.getBoundingClientRect();
        const h = Math.ceil(rect.height);
        const maxH = Math.floor(window.innerHeight * 0.85);
        iframe.style.height = Math.min(h, maxH) + 'px';
      };

      fit();
      new MutationObserver(fit).observe(doc.body, {subtree:true, childList:true, attributes:true, characterData:true});
      window.addEventListener('resize', fit);

    } catch (e) {
      // ignore cross-origin issues
    }
  });
});
</script>

<!-- Theme picker button -->
<button class="theme-fab" onclick="openThemeModal()" aria-label="Change theme">🎨</button>

<!-- Theme modal (simple palette) -->
<div class="theme-modal" id="themeModal">
  <div class="theme-card">
    <div class="theme-header">
      <h3>Select Theme</h3>
      <button class="modal-close" type="button" onclick="closeThemeModal()">×</button>
    </div>

    <!-- JS fills this with buttons -->
    <div class="theme-grid" id="themeList"></div>
  </div>
</div>

<script>
// small theme picker: saves to localStorage and applies to iframes too
function openThemeModal(){ document.getElementById('themeModal').classList.add('open'); }
function closeThemeModal(){ document.getElementById('themeModal').classList.remove('open'); }

function setTheme(name){
  if (name === 'default') {
    document.documentElement.removeAttribute('data-theme');
    localStorage.removeItem('theme');
  } else {
    document.documentElement.setAttribute('data-theme', name);
    localStorage.setItem('theme', name);
  }

  // push theme into same-origin iframes (our edit dialogs)
  document.querySelectorAll('iframe').forEach(f => {
    try {
      const d = f.contentDocument || f.contentWindow?.document;
      if (!d) return;
      if (name === 'default') d.documentElement.removeAttribute('data-theme');
      else d.documentElement.setAttribute('data-theme', name);
    } catch(_) {}
  });

  highlightActiveTheme();
  closeThemeModal();
}

const THEMES = [
  {key:'default',      name:'Default',      sw1:'#4f46e5', sw2:'#e0e7ff'},
  {key:'professional', name:'Professional', sw1:'#1d4ed8', sw2:'#dde3ee'},
  {key:'smart',        name:'Smart',        sw1:'#0d9488', sw2:'#d7ecec'},
  {key:'fairy',        name:'Fairy',        sw1:'#8b5cf6', sw2:'#eae4ff'},
  {key:'forest',       name:'Forest',       sw1:'#14532d', sw2:'#d9efe3'},
  {key:'ocean',        name:'Ocean',        sw1:'#0284c7', sw2:'#d6e7f1'},
  {key:'sunset',       name:'Sunset',       sw1:'#f97316', sw2:'#ffe6cc'},
  {key:'mono',         name:'Mono',         sw1:'#374151', sw2:'#e5e7eb'},
  {key:'solar',        name:'Solar',        sw1:'#ca8a04', sw2:'#f3e8aa'},
];

function renderThemePicker(){
  const container = document.getElementById('themeList');
  if (!container) return;

  container.innerHTML = '';
  THEMES.forEach(t => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'theme-option';
    btn.dataset.themeKey = t.key;
    btn.setAttribute('aria-pressed', 'false');
    btn.title = t.name;
    btn.onclick = () => setTheme(t.key);

    // little colour swatch for the theme
    const swatch = document.createElement('div');
    swatch.className = 'swatch';
    swatch.style.setProperty('--sw1', t.sw1);
    swatch.style.setProperty('--sw2', t.sw2);
    btn.appendChild(swatch);

    const label = document.createElement('span');
    label.className = 'theme-name';
    label.textContent = t.name;
    btn.appendChild(label);

    container.appendChild(btn);
  });

  highlightActiveTheme();
}

function highlightActiveTheme(){
  const saved = localStorage.getItem('theme') || 'default';
  document.querySelectorAll('#themeList .theme-option').forEach(btn => {
    const isActive = btn.dataset.themeKey === saved;
    btn.classList.toggle('is-active', isActive);
    btn.setAttribute('aria-pressed', String(isActive));
  });
}

// apply saved theme and build the picker
document.addEventListener('DOMContentLoaded', () => {
  const saved = localStorage.getItem('theme');
  if (saved) document.documentElement.setAttribute('data-theme', saved);
  renderThemePicker();
});
</script>

</body>
</html>
