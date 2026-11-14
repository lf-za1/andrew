/*
 * SploitGoldHEN 14.02
 * The landing page always routes to the bundled GoldHEN loader.
 * jb.js requires this same-origin index.html referrer as an intentional
 * launch guard, so keep this navigation rather than linking directly to jb.html.
 */
(function () {
  "use strict";
  var status = document.getElementById("launch-status");
  var started = false;

  function launchGoldHEN() {
    if (started) return;
    started = true;
    if (status) status.textContent = "Launching the 14.02 exploit chain...";
    window.location.replace(
      "jb.html?log=1&afterglow=run&mode=goldhen"
    );
  }

  // Let the branded launch screen paint before navigating into the exploit.
  if (/PlayStation 4/i.test(navigator.userAgent || "")) {
    window.setTimeout(launchGoldHEN, 900);
  } else if (status) {
    status.textContent = "Open this host in the PS4 browser to launch GoldHEN.";
  }
})();
