module ApplicationHelper
  def warning_icon(css_class: "size-4 shrink-0")
    tag.svg(xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 20 20", fill: "#fab219", class: css_class, "aria-hidden": "true") do
      tag.path(
        "fill-rule": "evenodd",
        d: "M9.401 1.596c.376-.65 1.322-.65 1.698 0l7.86 13.598c.375.65-.093 1.463-.849 1.463H2.39c-.756 0-1.224-.813-.849-1.463L9.401 1.596ZM10 5a.75.75 0 0 1 .75.75v3.5a.75.75 0 0 1-1.5 0v-3.5A.75.75 0 0 1 10 5Zm0 8a1 1 0 1 0 0-2 1 1 0 0 0 0 2Z",
        "clip-rule": "evenodd"
      )
    end
  end
end
