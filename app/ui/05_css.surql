-- Design tokens + the few rules utilities cannot express (served at /ui.css). Everything else is UnoCSS utilities (see fn::ui::k).
DEFINE FUNCTION OVERWRITE fn::ui::css() -> string {
	RETURN '
:root{--bg:#fff;--fg:#171717;--muted:#6b6b6b;--line:#e5e5e5;--surface:#f7f7f8;--surface2:#eee;--red:#e30613;--red-d:#b8000b;--btn:#e30613;--ok:#15803d;--ok-bg:#e8f5ec;--warn:#92400e;--warn-bg:#fdf1d8;--r:12px;--sans:Inter,system-ui,-apple-system,Segoe UI,Roboto,sans-serif;--disp:Montserrat,Inter,system-ui,sans-serif;--mono:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;color-scheme:light}
:root[data-theme=dark]{--bg:#212121;--fg:#f5f5f5;--muted:#b5b5b5;--line:#454545;--surface:#2f2f2f;--surface2:#3a3a3a;--red:#ff4b55;--red-d:#e63842;--ok:#4ade80;--ok-bg:#1d3a28;--warn:#fbbf24;--warn-bg:#3d3216;color-scheme:dark}
@media (prefers-color-scheme:dark){:root:not([data-theme]){--bg:#212121;--fg:#f5f5f5;--muted:#b5b5b5;--line:#454545;--surface:#2f2f2f;--surface2:#3a3a3a;--red:#ff4b55;--red-d:#e63842;--ok:#4ade80;--ok-bg:#1d3a28;--warn:#fbbf24;--warn-bg:#3d3216;color-scheme:dark}}
*,*::before,*::after{box-sizing:border-box;border:0 solid var(--line)}
h1,h2,h3,h4,p,ul,body{margin:0}
ul{padding:0;list-style:none}
button,input{font:inherit;color:inherit}
img,svg{display:block;max-width:100%}
html{-webkit-text-size-adjust:100%;background:var(--bg)}
a{color:inherit}
[hidden],[x-cloak],[un-cloak]{display:none!important}
:focus-visible{outline:2px solid var(--red);outline-offset:2px}
.skip:not(:focus){clip-path:inset(50%)}
.dd-btn[aria-expanded=true]{border-color:var(--red)}
.dd-panel:has(input:focus-visible) .dd-search{box-shadow:inset 0 -2px 0 var(--red)}
.dd-panel:not(:has(li:not([hidden]))) .dd-none{display:block}
.dd-panel ul{scrollbar-width:thin}
a.course-link::after{content:"";position:absolute;inset:0}
.course:has(a.course-link:focus-visible){outline:2px solid var(--red);outline-offset:-2px}
.busy{display:none}
.app.htmx-request .busy{display:block}
.app.htmx-request .results{opacity:.45;pointer-events:none}
.htmx-request .btn .ico{animation:spin 1s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
@media(prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
';
};
