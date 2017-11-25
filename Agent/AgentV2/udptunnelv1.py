#!/usr/bin/env python
from flask import Flask, jsonify
from flask import request
import subprocess
import threading
import time
from threading import Thread
import sys
import socket
import select
import errno
import pytun
import argparse 
import json
import pdb
import logging
import os
import platform

app = Flask(__name__)

g_server=None
logger=None

class UDPServer(object):

   def __init__(self, dport, cport):
      logger.debug('UDPServer constructor called')
      self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
      self.sock.bind(('0.0.0.0', dport))
      self.dport = dport

      self.control = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
      self.control.bind(('0.0.0.0', cport))
      self.cport = cport

      logger.debug("Listening for control event on UDP Port %d, data on port %d" % (cport, dport))

      self.tunnels = {}
      self.remoteServer = {}

      self.to_tun = {}
      self.to_sock = {}
   
      self.rlist = [ self.sock, self.control ]  
      self.wlist = [ ]
      self.xlist = [ ]

   def addTunnel(self, t):

       localAddr =  t.get('tunnelIP', None)
       tunnelname = t.get('name', None)
       netmask = t.get('netmask', None)
       remoteServerIP = t.get('remoteServer', None)
       mtu = t.get('mtu', 8980)

       if ((localAddr is None) or 
           (tunnelname is None) or 
           (netmask is None) or 
           (remoteServerIP is None)): 
           logger.debug("Invalid param addr:%s, name:%s, mask:%s remoteServer:%s" % 
               (localAddr, tunnelname, netmask, remoteServerIP))
           return 

       logger.debug("Adding tunnel %s" % str(t))
       #tun = self.getTunnel(remoteServerIP)
       
       #if tun is None:           	
       tun = pytun.TunTapDevice(name=tunnelname)
       #tun.name = tunnelname     
       tun.addr = localAddr
       tun.netmask = netmask
       tun.mtu = mtu
       tun.up()
 
       self.tunnels[remoteServerIP] = tun
       self.remoteServer[tun.name] = remoteServerIP
       self.rlist.append(tun)

   def getTunnels(self):
       return self.tunnels.values()		
		
   def getTunnel(self, remoteServerIP):
       return self.tunnels.get(remoteServerIP, None)
      
   def getRemoteServer(self, tunnelName):
       return self.remoteServer.get(tunnelName, None)

   def delTun(self, t):
       name = t.get('name', None)
       remoteServerIP = self.getRemoteServer(name)
       tunnel = self.getTunnel(remoteServerIP)
   
       if remoteServerIP == None: 
          #print "Remote server Not Found for tunnel %s" % name
          return 

       if tunnel == None: 
          #print "Tunnel %s not found" % name
          return 

       logger.debug("deleting tunnel %s" % str(t))
       del self.tunnels[remoteServerIP]
       del self.remoteServerIP[name]

       self.rlist.remove(tunnel)
       tunnel.close()

   def updateServer(self, msg):
       m = json.loads(msg)
       op = m.get('op', None)

       tunnels = m.get('tunnel', [])
       logger.debug("update server with operation: %s" % str(op))

       for tunnel in tunnels: 
           if op == 'add': 
              self.addTunnel(tunnel)
           elif op == 'del': 
              self.delTunnel(tunnel)
           else: 
              logger.debug("Invalid operation: %s" % op)
       
   def run(self):
       logger.debug('Starting UDP server')
       self.to_sock = {}
       self.to_tun = {} 

       while True: 
          try: 
             r, w, z = select.select(self.rlist, self.wlist, self.xlist, 5)

             #logger.debug("Received an event: ")
             #logger.debug(r)

             #
             # Check if any data was received from any Tunnel interface 
             #
             for rs, tun in self.tunnels.iteritems():
                 if tun in r:
                    # 
                    # Add the packet to be sent to remote server 
                    # as a tuple 
                    #  (remoteServerAddr, data) 
                    #
                    self.to_sock[rs] = tun.read(tun.mtu)
                    #pkt = ' 0x'.join(hex(ord(x))[2:] for x in to_sock)
                    #logger.debug(pkt)
                    #logger.debug("received pkt")
 
             #
             # Check if data was received from socket interface 
             #
             if self.sock in r:
                 to_tun, addr = self.sock.recvfrom(65535)
                 #
                 # Lookup tunnel interface based on 
                 # sender IP address 
                 #
                 tun = self.getTunnel(addr[0])

                 if tun:
                    #
                    # Add packets to be sent to the Tunnel
                    # Cache it as a tuple
                    #   (tunnel, data) 
                    #
                    self.to_tun[tun.name] = (tun, to_tun)
                    #logger.debug("Pkt sent to tunnel: %s" % str(tun.name))
                 ''' 
                 else: 
                    print "No tunnel found for server IP %s" % str(addr[0])
                 '''

             if self.control in r: 
                controlMessage, caddr = self.control.recvfrom(65535)
                #print "Received Control Message %s" % str(controlMessage)
                self.updateServer(controlMessage)
                  
             #
             # Write data to tunnel
             #
             for name, (tun, data) in self.to_tun.iteritems():
                  tun.write(data)

             self.to_tun = {}

             #
             # Write data to socket 
             #
             for (raddr, to_sock) in self.to_sock.iteritems():
                 self.sock.sendto(to_sock, (raddr, self.dport))
                 #pkt = ' 0x'.join(hex(ord(x))[2:] for x in to_sock)
                 #logger.debug(pkt)
                 #logger.debug("sending packet to remote side")

             self.to_sock = {}

          except (select.error, socket.error, pytun.Error), e:
                if e[0] == errno.EINTR:
                    continue
                #logger.error(str(e))
                break

def getOptions():
    tunnelIP = ''
    remoteServerIP = ''
    dp = None
    cp = None
    mtu = None
    name = None

    parser = argparse.ArgumentParser(description='UDP proxy Server ')
    parser.add_argument('-dp','--dataPort', 
                        help='UDP Proxy Server data port', 
                        type=int, default=1194)
    parser.add_argument('-cp','--controlPort', 
                        help='UDP Proxy Server control port', 
                        type=int, default=1195)
    args = vars(parser.parse_args())
 
    dp = args.get('dataPort', None)
    cp = args.get('controlPort', None)

    return (dp, cp)

def runudpserver():
   global g_server
   #pdb.set_trace()
   g_server.run() 	

@app.route('/udpproxy/gettunnels', methods=['GET'])
def gettunnels():
    logger.debug('Call to get tunnels')
    global g_server
    tunnames = []
    for ltun in g_server.getTunnels():
	tunnames.append(ltun.name)

    return jsonify({'tunnels' :tunnames})

@app.route('/udpproxy/addtunnels', methods=['POST'])
def addtunnels():
    global g_server
    for tunnel in request.json['tunnel']:
	if request.json['op'] == "add":
            logger.debug('REST CALL to ADD Tunnel')
	    g_server.addTunnel(tunnel)
        else:
            logger.debug('REST CALL to DEL Tunnel')
            g_server.delTunnel(tunnel)

    return jsonify({}), 201


def setLogger():
    global logger
    logger = logging.getLogger('udptunnel')
    logging.basicConfig(filename="/var/log/udptunnel.log",
                        format='%(asctime)s %(levelname)s %(message)s')
    logger.setLevel(logging.DEBUG)

    #fh = logging.FileHandler("/var/log/udptunnel.log", "w")
    #fh.setLevel(logging.DEBUG)
    #logger.addHandler(fh)
    
    #
    # Detach stdout, stdin and stderr for daemonizing 
    #
    f = open('/dev/null', 'w')
    sys.stdout = f
    sys.stderr = f
    sys.stdin.close()

    logger.debug('stdout/stderr redirected to /dev/null ...')

    return logger

def daemonizeDebian():
    logger.debug('stdout/stderr redirected to /dev/null ...')

    # Fork, creating a new process for the child.
    process_id = os.fork()

    if process_id < 0:
        # Fork error.  Exit badly.
        sys.exit(1)
        logger.debug('Fork Error')
    elif process_id != 0:
        # This is the parent process.  Exit.
        sys.exit(0)
    # This is the child process.  Continue.

    logger.debug('Process ID before setid(): %s' % str(process_id))
    # Stop listening for signals that the parent process receives.
    # This is done by getting a new process id.
    # setpgrp() is an alternative to setsid().
    # setsid puts the process in a new parent group and detaches its
    # controlling terminal.
    process_id = os.setsid()
    if process_id == -1:
        # Uh oh, there was a problem.
        logger.debug('Set ID Failed')
        sys.exit(1)

    process_id = os.getpid()
    logger.debug('Process ID after setid(): %s...' % str(process_id))
    
    #
    # Create PID file for tracking service 
    #
    pidfile = open('/var/run/udptunnel', 'w')
    pidfile.write("%d" % process_id)
    pidfile.close()

    # Set umask to default to safe file permissions when running
    # as a root daemon. 027 is an octal number.
    os.umask(027)

    # Change to a known directory.  If this isn't done, starting
    # a daemon in a subdirectory that needs to be deleted results
    # in "directory busy" errors.
    # On some systems, running with chdir("/") is not allowed,
    # so this should be settable by the user of this library.
    os.chdir('/')

    logger.debug('Daemonization complete')

def daemonizeUbuntu():

    # Fork, creating a new process for the child.
    '''
    #
    # NOTE: Ubuntu upstart for some reason does not like fork
    # 
    # Even with 'expect fork' stanza in the start up script
    # ubuntu upstart seems to track incorrect PID. As a result 
    # daemon stop does not work 
    #
    # Experimented with 'expect daemon' that didn't help
    # Disabling fork seems to work fine... 
    #
    process_id = os.fork()

    if process_id < 0:
        # Fork error.  Exit badly.
        sys.exit(1)
        logger.debug('Fork Error')
    elif process_id != 0:
        # This is the parent process.  Exit.
        sys.exit(0)
    # This is the child process.  Continue.

    logger.debug('Process ID before setid(): %s' % str(process_id))
    # Stop listening for signals that the parent process receives.
    # This is done by getting a new process id.
    # setpgrp() is an alternative to setsid().
    # setsid puts the process in a new parent group and detaches its
    # controlling terminal.
    process_id = os.setsid()
    if process_id == -1:
        # Uh oh, there was a problem.
        logger.debug('Set ID Failed')
        sys.exit(1)

    '''

    process_id = os.getpid()
    logger.debug('Process ID after setid(): %s...' % str(process_id))
    
    pidfile = open('/var/run/udptunnel', 'w')
    pidfile.write("%d" % process_id)
    pidfile.close()

    # Set umask to default to safe file permissions when running
    # as a root daemon. 027 is an octal number.
    os.umask(027)

    # Change to a known directory.  If this isn't done, starting
    # a daemon in a subdirectory that needs to be deleted results
    # in "directory busy" errors.
    # On some systems, running with chdir("/") is not allowed,
    # so this should be settable by the user of this library.
    os.chdir('/')

    logger.debug('Daemonization complete')

def getLinuxDistro():
    dist = platform.dist()
    return dist[0]


def main():
   global g_server

   (dp, cp) = getOptions()
   if (dp is None) or (cp is None): 
       logger.debug("Invalid Ports - data port: %d, control port %d" % (dp, cp))

   
   logger.debug("Launching server with data port:%d, control port:%d" % (dp, cp))
   g_server = UDPServer(dp, cp)
   g_server.run()
    
if __name__ == '__main__':
   setLogger()

   logger.debug("Initializing Daemon")
   daemonizeUbuntu()   

   logger.debug("Daemon launched, start main udp server thread")

   thread = Thread(target = main, args = [])
   thread.setDaemon(True)
   thread.start()

   logger.debug("Launch REST interface")

   app.run(host='0.0.0.0', port=60036, debug=True, use_reloader=False) 

