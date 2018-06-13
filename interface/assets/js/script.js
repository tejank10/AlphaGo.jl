var game = {};
const $$ = (e) => document.querySelector(e);

function __init__(){
  console.log("__init__")
  // setup board
  var config = {
      width: 500,
      section: {
          top: -1,
          left: -1,
          right: -1,
          bottom: -1
      }
  }

  var board =  new WGo.Board($$("#playground"), config)

  console.log(board)

  board.addEventListener("click", function(x, y){
      console.log(x.toString() + " " + y.toString())
      game.action({type: "stone", x, y, c: WGo.B});
  })

  function setBoardSize(int){
    console.log(int)
    board.setSize(Math.floor(int))
  }

  function update(env){
      board.addObject(env.action)
      setTimeout(() => board.restoreState(env.state), 500);
  }

  function showMsg(msg){

      $$("#msg").innerText = msg.toString();
      show($$("msg"))
      setTimeout(()=>hide($$("msg")), 3000)
  }

  game = Object.assign(game, {
    setBoardSize,
    update,
    showMsg
  })


  // draw coordinates
  var coordinates = {
        // draw on grid layer
        grid: {
            draw: function(args, board) {
                var ch, t, xright, xleft, ytop, ybottom;

                this.fillStyle = "rgba(0,0,0,0.7)";
                this.textBaseline="middle";
                this.textAlign="center";
                this.font = board.stoneRadius+"px "+(board.font || "");

                xright = board.getX(-0.75);
                xleft = board.getX(board.size-0.25);
                ytop = board.getY(-0.75);
                ybottom = board.getY(board.size-0.25);

                for(var i = 0; i < board.size; i++) {
                    ch = i+"A".charCodeAt(0);
                    if(ch >= "I".charCodeAt(0)) ch++;

                    t = board.getY(i);
                    this.fillText(board.size-i, xright, t);
                    this.fillText(board.size-i, xleft, t);

                    t = board.getX(i);
                    this.fillText(String.fromCharCode(ch), t, ytop);
                    this.fillText(String.fromCharCode(ch), t, ybottom);
                }

                this.fillStyle = "black";
    		}
        }
    }
    board.addCustomObject(coordinates);


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
}
