use http-nu/html *
use http-nu/router *
use http-nu/datastar *

def nav-key [key: string, --down] {
  let color = if $down { "#f8f8f2" } else { "#6272a4" }
  SPAN {style: {
    font-family: ["SF Mono" "Fira Code" "JetBrains Mono" monospace]
    font-size: 8em
    font-weight: bold
    color: $color
  }} $key
}

def nav-keys [down: record] {
  NAV {id: "nav-keys" style: {display: flex justify-content: space-around width: "80%" margin-top: 2em}} [
    (nav-key H --down=($down.h))
    (nav-key J --down=($down.j))
    (nav-key K --down=($down.k))
    (nav-key L --down=($down.l))
    ]
}

{|req|
  dispatch $req [
    (route {path: "/"} {|req ctx|
      let slides = ls slides/*.md | get name | sort
      let content = open ($slides | first) | .md

      (HTML
        (HEAD
          (META {charset: "utf-8"})
          (META {name: "viewport" content: "width=device-width, initial-scale=1"})
          (LINK {rel: "stylesheet" href: "/style.css"})
          (SCRIPT {type: "importmap"} {__html: $'{"imports":{"datastar":"($DATASTAR_CDN_URL)"}}'})
          (SCRIPT {type: "module" src: $DATASTAR_CDN_URL})
          (SCRIPT {type: "module" src: "https://cdn.jsdelivr.net/npm/@mbolli/datastar-attribute-on-keys@1/dist/index.js"} "")
        )
        (BODY {data-init: "@get('/sse')"}
          (DIV
            {
              "data-on-keys:h": "@get('/press/down/h')"
              "data-on-keys:j": "@get('/press/down/j')"
              "data-on-keys:k": "@get('/press/down/k')"
              "data-on-keys:l": "@get('/press/down/l')"
              "data-on-keys:h__up": "@get('/press/up/h')"
              "data-on-keys:j__up": "@get('/press/up/j')"
              "data-on-keys:k__up": "@get('/press/up/k')"
              "data-on-keys:l__up": "@get('/press/up/l')"
              "data-on-keys:ctrl-l": "@get('/nav/next')"
              "data-on-keys:ctrl-h": "@get('/nav/prev')"
            }
          )
          (ARTICLE {id: "content"} $content)
          (nav-keys {h: false, j: false, k: false, l: false})
        )
      )
    })

    (route {method: "GET", path: "/sse"} {|req ctx|
      let slides = ls slides/*.md | get name | sort

      .cat --follow --new
      | generate {|frame, state|
        let state = match $frame.topic {
          "press" => ($state | upsert keys ($state.keys | upsert $frame.meta.key ($frame.meta.action == "down")))
          "nav" => {
            let idx = match $frame.meta.action {
              "next" => ([($state.slide + 1) (($slides | length) - 1)] | math min)
              "prev" => ([($state.slide - 1) 0] | math max)
              _ => $state.slide
            }
            $state | upsert slide $idx
          }
          _ => $state
        }

        let patches = match $frame.topic {
          "press" => [(nav-keys $state.keys | to datastar-patch-elements)]
          "nav" => [
            (ARTICLE {id: "content"} (open ($slides | get $state.slide) | .md)
            | to datastar-patch-elements)
          ]
          _ => []
        }

        {out: $patches, next: $state}
      } {keys: {h: false, j: false, k: false, l: false}, slide: 0}
      | flatten
      | to sse
    })

    (route {method: "GET", path-matches: "/press/:action/:key"} {|req ctx|
      null | .append press --meta {key: $ctx.key, action: $ctx.action} --ttl ephemeral | ignore
    })

    (route {method: "GET", path-matches: "/nav/:action"} {|req ctx|
      null | .append nav --meta {action: $ctx.action} --ttl ephemeral | ignore
    })

    (route true {|req ctx|
      .static "./static" $req.path
    })
  ]
}
