// helper functions for showing messages
var $$ = (e) => document.querySelector(e);
function injectMsgBox(){
  var msg = document.createElement("div");
  msg.setAttribute("id", "#msg");
  msg.setAttribute("className", "hidden");
  document.body.appendChild(msg);s
}

function showMsg(msg){
    $$("#msg").innerText = msg.toString();
    show($$("#msg"))
    setTimeout(()=>hide($$("#msg")), 3000)
}

function show(ele){
  if(ele.className.match("hidden") != null){
    ele.className = ele.className.replace("hidden", "");
  }
}

function hide(ele){
  if(ele.className.match("hidden") == null){
    ele.className += " hidden";
  }
}

var game = { showMsg }

// set game.update and call game.action according to the game
