import net, posix, strutils

proc exitSuccessfully(code: cint) {.noconv.}=
  echo "Quitting (Ctrl-C)"
  quit(0)

# Simple echo server that writes input to STDOUT
proc main() =
  const
    port = 9093

  let mySocket = newSocket()
  bindAddr(socket= mySocket, port = Port(port))
  mySocket.listen()

  echo "Listening on: $1:$2".format(mySocket.getLocalAddr()[0], mySocket.getLocalAddr()[1])
  signal(SIGINT,exitSuccessfully)

  var clientSock = newSocket()
  var inputFromClient = newStringOfCap(80)

  while true:
    mySocket.accept(clientSock)
    clientSock.readLine(inputFromClient)
    echo inputFromClient
    clientSock.close()




when isMainModule:
  main()
