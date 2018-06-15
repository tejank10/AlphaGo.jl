var $$ = e => document.querySelector(e);
function __init__(){
  // setup board
  var boardConfig = {
      width: 500,
      section: {
          top: -1,
          left: -1,
          right: -1,
          bottom: -1
      }
  }

  var board =  new WGo.Board($$("#playground"), boardConfig)

  board.setSize(Math.floor(game.config.boardSize))

  board.addEventListener("click", function(x, y){
      console.log("clicked")
      var action = {type: "NORMAL", x, y, c: WGo.B};
      game.action(action);
  })

  function update(env){
      if(env.action.x != -1 && env.action.y != -1 ){
          var action = Object.assign({}, env.action,{"type": "NORMAL"})
          board.addObject(action)
          setTimeout(() => board.restoreState(env.state), 500);
      }
  }

  $$("#controls .pass").addEventListener("click", function (e){
      game.action({x: -1, y: -1, c:WGo.B});
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
                this.font = board.stoneRadius+"px "+(board.font || "Lato");

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

    game = Object.assign(game, {
      update,
      showMsg
    })
}
