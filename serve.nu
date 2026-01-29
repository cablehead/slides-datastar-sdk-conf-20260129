use http-nu/html *
use http-nu/router *

{|req|
  dispatch $req [
    (route {path: "/"} {|req ctx|
      let content = open slide.md | .md

      (HTML
        (HEAD
          (META {charset: "utf-8"})
          (META {name: "viewport" content: "width=device-width, initial-scale=1"})
          (LINK {rel: "stylesheet" href: "/style.css"})
        )
        (BODY
          (ARTICLE $content)
        )
      )
    })

    (route true {|req ctx|
      .static "./static" $req.path
    })
  ]
}
