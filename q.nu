
use http-nu/datastar *
use http-nu/html *

DIV "hi" | to datastar-patch-elements | to sse

