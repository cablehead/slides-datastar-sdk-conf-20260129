use http-nu/html *
use http-nu/router *
use http-nu/datastar *

def slide-content [file: string] {
  print $file
  ARTICLE {id: "content" style: {flex: 1 display: flex flex-direction: column align-items: center justify-content: center}} (open $file | {__html: $in} | .md)
}

def head-common [] {
  [
    (META {charset: "utf-8"})
    (META {name: "viewport" content: "width=device-width, initial-scale=1"})
    (LINK {rel: "stylesheet" href: "/style.css"})
    (SCRIPT {type: "importmap"} {__html: $'{"imports":{"datastar":"($DATASTAR_CDN_URL)"}}'})
    (SCRIPT {type: "module" src: $DATASTAR_CDN_URL})
    (SCRIPT {type: "module" src: "https://cdn.jsdelivr.net/npm/@mbolli/datastar-attribute-on-keys@1/dist/index.js"} "")
  ]
}

def nav-key [key: string, --down] {
  let color = if $down { "#f8f8f2" } else { "#6272a4" }
  SPAN {style: {
    font-family: ["SF Mono" "Fira Code" "JetBrains Mono" monospace]
    font-size: 12em
    font-weight: bold
    color: $color
  }} $key
}

def nav-keys [down: record] {
  NAV {id: "nav-keys" style: {
    display: flex
    justify-content: space-around
    align-items: center
    flex: 1
  }
  } [
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

      (HTML
        (HEAD ...(head-common))
        (BODY {data-init: "@get('/sse')" style: {display: flex flex-direction: column}}
          (HEADER {style: {display: flex justify-content: flex-end}}
            (A {href: "/spacebar"} "spacebar") (SPAN {style: {width: 2em display: inline-block}}) (A {href: "/hjkl"} "hjkl")
          )
          (DIV
            {
              "data-on-keys:ctrl-l": "@get('/nav/next')"
              "data-on-keys:ctrl-h": "@get('/nav/prev')"
            }
          )
          (slide-content ($slides | first))
        )
      )
    })

    (route {method: "GET", path: "/sse"} {|req ctx|
      let slides = ls slides/*.md | get name | sort

      .cat --follow --new -T nav
      | generate {|frame, state|
        let idx = match $frame.meta.action {
          "next" => ([($state + 1) (($slides | length) - 1)] | math min)
          "prev" => ([($state - 1) 0] | math max)
          _ => $state
        }
        let html = slide-content ($slides | get $idx)
        {out: ($html | to datastar-patch-elements), next: $idx}
      } 0
      | to sse
    })

    (route {path: "/spacebar"} {|req ctx|
      (HTML
        (HEAD ...(head-common))
        (BODY {data-init: "@get('/spacebar/sse')" style: {display: flex flex-direction: column}}
          (HEADER {style: {display: flex justify-content: flex-start}}
            (NAV (A {href: "/"} "home") " / spacebar")
          )
          (DIV {"data-on-keys:space": "@get('/spacebar/press')"})
          (DIV {id: "spacebar-count" style: {
            flex: 1
            display: flex
            flex-direction: column
            align-items: center
            justify-content: center
          }} [
            (SPAN {style: {
              font-family: ["SF Mono" "Fira Code" "JetBrains Mono" monospace]
              font-size: 12em
              font-weight: bold
              color: "#bd93f9"
            }} "0")
            (P {style: {color: "#6272a4" margin-top: "0.5em"}} "press the space bar")
          ])
        )
      )
    })

    (route {method: "GET", path: "/spacebar/press"} {|req ctx|
      null | .append spacebar --meta {req: $req} | ignore
    })

    (route {method: "GET", path: "/spacebar/sse"} {|req ctx|
      .cat --follow -T spacebar
      | generate {|frame, state|
        let count = $state + 1
        let html = DIV {id: "spacebar-count" style: {
          flex: 1
          display: flex
          flex-direction: column
          align-items: center
          justify-content: center
        }} [
          (SPAN {style: {
            font-family: ["SF Mono" "Fira Code" "JetBrains Mono" monospace]
            font-size: 12em
            font-weight: bold
            color: "#bd93f9"
          }} ($count | into string))
          (P {style: {color: "#6272a4" margin-top: "0.5em"}} "press the space bar")
        ]
        {out: ($html | to datastar-patch-elements), next: $count}
      } 0
      | to sse
    })

    (route {path: "/hjkl"} {|req ctx|
      (HTML
        (HEAD ...(head-common))
        (BODY {data-init: "@get('/hjkl/sse')" style: {display: flex flex-direction: column}}
          (HEADER {style: {display: flex justify-content: flex-start}}
            (NAV (A {href: "/"} "home") " / hjkl")
          )
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
            }
          )
          (nav-keys {h: false, j: false, k: false, l: false})
        )
      )
    })

    (route {method: "GET", path: "/hjkl/sse"} {|req ctx|
      .cat --follow --new --topic press
      | generate {|frame, state={h: false, j: false, k: false, l: false}|
        let state = $state | upsert $frame.meta.key ($frame.meta.action == "down")
        {out: (nav-keys $state | to datastar-patch-elements), next: $state}
      }
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
