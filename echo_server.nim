# Heavily based on https://ruslanspivak.com/lsbaws-part3/
import net, posix, strutils

let mySocket = newSocket()

proc handleConnection(clientSocket: var Socket) =
  var inputFromClient: string = newStringOfCap(80)
  # This is a slightly fucked way of doing things - should have maximum amount
  # that we read from client instead of just reading forever.
  clientSocket.readLine(inputFromClient)
  # Don't take any guff - give it right back to 'em
  clientSocket.send("SERVED BY Nim: " & inputFromClient & "\n")
  # Simulate load but disconnect first
  clientSocket.close
  discard sleep(3)


proc exitSuccessfully(code: cint) {.noconv.}=
  echo "Quitting process $# (Ctrl-C)".format($getPid())
  mySocket.close
  quit(0)

proc handleChildren(code: cint) {.noconv.} =
  var status: cint = 0
  while true:
    let pid = posix.waitpid(-1.Pid, status, WNOHANG)

    # Return on error or if no child jobs changed state
    if pid == 0 or pid < 0: return
    else: echo "Worker $# is shutting down" % [$pid]

# Simple echo server that writes input to STDOUT
proc main() =
  const port = 9093

  # Allow socket port to be reused on exit so that we don't have to wait for OS
  # to clean up after daemon quits.
  mySocket.setSockOpt(opt = OptReuseAddr, value = true)

  bindAddr(socket = mySocket, port = Port(port))
  mySocket.listen()

  let (host, _) = mySocket.getLocalAddr()
  echo "Listening on: $1:$2".format(host,port)

  signal(SIGINT,exitSuccessfully)
  signal(SIGTERM,exitSuccessfully)
  signal(SIGCHLD,handleChildren)

  var clientSock = newSocket()

  # Want to fork and keep listening for connections
  while true:
    try:
      mySocket.accept(clientSock)
    except OSError:
      # Explicity type conversion needed to OSError since getCurrentException
      # returns the base class.
      let e = (ref OSError) getCurrentException()
      if e.errorCode == EINTR: continue
      else:
        mySocket.close
        raise e

    # TODO: How do we prefork N workers and make them all read from 'mySocket'?
    # Would need to keep array of N 'receiver' sockets with workers knowing which
    # value of 'N' they had, which might be hard.  They can inherit 'mySocket'
    # from the parent process - see if can accept requests without stepping on
    # each other.
    let pid = fork()
    if pid == 0:
      # Child process, so close the listening socket here.
      mySocket.close
      clientSock.handleConnection
      quit(0)
    else:
      # Main process, close the client socket.
      clientSock.close

when isMainModule:
  main()
