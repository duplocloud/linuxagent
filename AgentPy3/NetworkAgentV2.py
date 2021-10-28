#!/usr/bin/env python3
import requests
from flask import Flask, jsonify
from flask import request
import subprocess
import threading
import time
from threading import Thread
import socket
import pdb
import json
import argparse
import logging
import iptc
import sys
import traceback
import os
import platform
import docker
from logging import handlers, Formatter

app = Flask(__name__)

g_udpmode = False
logger = None
currentContainers = {}
TenantID = 'Empty'
RegistryToken = 'Empty'
EngineEndpoint = 'Empty'
NetworkProvider = 'custom'
g_RequiredImages = None


class Minion:
    def __init__(self, name, subnet, directAddress, directIpAddr):
        self.name = name
        self.subnet = subnet
        self.directAddress = directAddress
        self.directIpAddress = directIpAddr

    def isEqual(self, minion):
        val = False
        if self.name != minion.name:
            val = False
        elif self.subnet != minion.subnet:
            val = False
        elif self.directAddress != minion.directAddress:
            val = False
        else:
            val = True

        if val:
            logger.debug('Minions ' + self.name + ' and ' + minion.name + ' are equal')
        else:
            logger.debug('Minions ' + self.name + ' and ' + minion.name + ' are not equal')

        return val

    def log(self):
        val = self.name + ' ' + self.subnet + ' ' + self.directAddress + ' ' + self.directIpAddress
        return val


def addRoute(aInSubnet, aInTunnelName):
    lSubnetParts = aInSubnet.split(".")
    lSubnet = lSubnetParts[0] + "." + lSubnetParts[1] + "." + lSubnetParts[2] + ".0"
    logger.debug('Adding Routes to ' + lSubnet + "via " + aInTunnelName)
    # sudo route add -net 172.17.51.0 netmask 255.255.255.0 dev tun1
    val = subprocess.check_output(
        ["sudo", "route", "add", "-net", lSubnet, "netmask", "255.255.255.0", "dev", aInTunnelName])
    if val != "":
        lStatus = val.decode("utf-8")
        logger.debug(lStatus)

def getCurrentTunnels():
    val = subprocess.check_output(["sudo", "iptunnel", "show"])
    lStatus = val.decode("utf-8")
    lTunnels = lStatus.splitlines()
    lCurrentTuns = {}
    for lTun in lTunnels:
        lToks = lTun.split()
        lName = lToks[0].replace(":", "")
        if lName == 'gre0' or lName == 'tunl0':
            logger.debug('Skipping default tunnels')
        else:
            logger.debug('Existing Tunnel ' + lName)
            lCurrentTuns[lName] = lName

    return lCurrentTuns

def addTunnel(aInName, aInSubnet, aInLocalAddress, aInRemoteAddress):
    try:
        subprocess.check_output(
            ["sudo", "iptunnel", "add", aInName, "mode", "gre", "local", aInLocalAddress, "remote", aInRemoteAddress])
        subprocess.check_output(["sudo", "ifconfig", aInName, "up"])
        addRoute(aInSubnet, aInName)
    except:
        logger.error('Failed to add tunnel ' + aInName + ' will try again ***************************************')
        # deleteTunnelInDriver(lKey)

def deleteTunnel(aInName):
    try:
        subprocess.check_output(["sudo", "iptunnel", "del", aInName])
    except:
        logger.error('Failed to delete tunnel ' + aInName)

def updateTunnels(aInRemoteMinions, aInLocalMinion):
    logger.debug('Begin reconciling tunnels  ======================================================')
    lExpectedTuns = {}
    logger.debug('LOCAL*** ' + aInLocalMinion.log())
    lLocalAddr = aInLocalMinion.directIpAddress
    # Use the last two octets of the local and remmote IP as the tunnel name
    lLocalParts = lLocalAddr.split(".")
    lLocalSmallName = lLocalParts[2] + "." + lLocalParts[3]
    for lKey in aInRemoteMinions:
        val = aInRemoteMinions[lKey].log()
        logger.debug('REMOTE*** ' + val)
        lRemoteAddr = aInRemoteMinions[lKey].directIpAddress
        lRemoteParts = lRemoteAddr.split(".")
        lRemoteSmallName = lRemoteParts[2] + "." + lRemoteParts[3]
        lTunName = lLocalSmallName + '-' + lRemoteSmallName
        logger.debug('Adding a expected tunnel name ' + lTunName)
        lExpectedTuns[lTunName] = aInRemoteMinions[lKey]

    lCurrentTuns = getCurrentTunnels()

    lLocalAddr = aInLocalMinion.directIpAddress
    for lKey in lExpectedTuns:
        if  lKey not in  lCurrentTuns:
            logger.debug('Adding Tunnel ' + lKey)
            addTunnel(lKey, lExpectedTuns[lKey].subnet, lLocalAddr, lExpectedTuns[lKey].directIpAddress)
            logger.debug('Successfully Added Tunnel ' + lKey + ' +++++++++++++++++++++++++++++++++++++++++')

    for lKey in lCurrentTuns:
        if lKey not in  lExpectedTuns:
            try:
                logger.debug('Unwanted tunnel ' + lKey)
                deleteTunnel(lKey)
            except:
                logger.error('Failed to delete unwanted tunnel')

    logger.debug('End Reconciling Tunnels ======================================================')

    return

def addNetfilter(aInChain, aInRule, aInBlock):
    rule = iptc.Rule()
    match = rule.create_match("comment")
    match.comment = aInRule['Name']

    rule.dst = aInRule['DestAddress']

    if aInRule['SrcAddress']:
        rule.src = aInRule['SrcAddress']
    if aInRule['Protocol']:
        rule.protocol = aInRule['Protocol']
    if aInRule['BeginPort']:
        match = iptc.Match(rule, aInRule['Protocol'])
        match.dport = aInRule['BeginPort'] + ":" + aInRule['EndPort']
        rule.add_match(match)

    if aInBlock:
        rule.target = rule.create_target("DROP")
        aInChain.append_rule(rule)
    else:
        rule.target = rule.create_target("ACCEPT")
        aInChain.insert_rule(rule)

def deleteNetfilter(aInRuleName):
    table = iptc.Table(iptc.Table.FILTER)

    for chain in table.chains:
        if not str(chain.name) == 'FORWARD':
            continue
        for rule in chain.rules:
            for match in rule.matches:
                if str(match.name) == 'comment':
                    lRName = str(match.comment)
                    if lRName == aInRuleName:
                        logger.debug('DELETING RULE: ' + lRName)
                        chain.delete_rule(rule)
                        break
        break

def updateTopology():
    global TenantID
    global NetworkProvider

    if TenantID == 'Empty':
        logger.debug('TenantID has not been set yet')
        return
    logger.debug('Value of Network Provider is ' + NetworkProvider)
    if NetworkProvider == 'custom':
        logger.debug('Network provider is custom, no config needed by us')
        return

    hostName = socket.gethostname()
    localIpAddr = socket.gethostbyname(hostName)
    logger.debug(hostName + ' = ' + localIpAddr)

    url = EngineEndpoint + '/subscriptions/' + TenantID + '/GetMinions'
    logger.debug(url)
    r = requests.get(url)
    if r.status_code != requests.codes.ok:
        logger.debug("GET call failed ")
        return

    lFoundLocal = False
    rMinions = {}
    for lMinion in r.json():
        lname = lMinion['Name'].lower()
        try:
            ldirectAddress = lMinion['DirectAddress'].lower()
            logger.debug('Trying to resolve ' + ldirectAddress)
            ldirectIpAddress = socket.gethostbyname(ldirectAddress)
            logger.debug(ldirectAddress + ' = ' + ldirectIpAddress)
            lsubnet = lMinion['Subnet']
            if localIpAddr != ldirectIpAddress:
                logger.debug('Adding a remote Minion ' + lname)
                rMinions[lname] = Minion(lname, lsubnet, ldirectAddress, ldirectIpAddress)
            else:
                logger.debug('Adding a local minion ' + lname)
                localMinion = Minion(lname, lsubnet, ldirectAddress, ldirectIpAddress)
                lFoundLocal = True
        except:
            logger.error('Error in handling minion ' + lname)

    if not lFoundLocal:
        logger.error('Error we cannot find our own Minion')
        return

    updateTunnels(rMinions, localMinion)
    '''    
    try:
	updateNetfilters(localMinion)
    except Exception, e:
        nfltErr = "Couldn't do it: %s" % e
        logger.error("Error updating netfilters error: " + nfltErr)
    '''
    return


@app.route('/NetworkAgent/api/v1.0/UpdateMinionState', methods=['POST'])
def UpdateMinionState():
    global TenantID
    global RegistryToken
    global EngineEndpoint
    global NetworkProvider
    global g_udpmode
    global g_RequiredImages

    lSubnet = request.json['Subnet']
    lMinionName = request.json['Name']
    lMode = request.json['TunnelMode']

    NetworkProvider = 'default'

    RegistryToken = request.json['RegistryToken']
    if TenantID == 'Empty':
        TenantID = request.json['TenantID']
        EngineEndpoint = request.json['EngineEndpoint']

    logger.debug(request.json)
    if 'Images' in request.json:
        logger.debug('UpdateMinionState: Required Images has been set')
        if request.json['Images'] is not None:
            g_RequiredImages = list()
            for lImg in request.json['Images']:
                g_RequiredImages.append(lImg)
        logger.debug(g_RequiredImages)
    else:
        logger.debug('UpdateMinionState: Required Images was not set')

    return jsonify({}), 201


@app.route('/NetworkAgent/api/v1.0/GetTenantID', methods=['GET'])
def gettenantid():
    global TenantID
    return jsonify({'TenantID': TenantID})


def updateTopologyThread():
    while (True):
        time.sleep(10)
        try:
            updateTopology()
        except:
            logger.error('****************************** UpdateTopology encountered an exception')

        logger.debug('================================= updateTopology completed')


def downloadImage(aInImageName):
    global RegistryToken
    logger.debug('Starting downloading ... ' + aInImageName)
    lImageDwldUrl = 'http://127.0.0.1:4243/images/create?fromImage=' + aInImageName
    lPayload = {}

    headers = {'X-Registry-Auth': RegistryToken}
    r = requests.post(lImageDwldUrl, data=aInImageName, headers=headers)

    if r.ok:
        logger.debug('Finished downloading repo ' + aInImageName)
    else:
        logger.debug('image download failed with return code and message' + str(r.status_code) + " " + str(r.json()))
        logger.debug('Trying image download without docker creds for image - ' + aInImageName)
        r = requests.post(lImageDwldUrl, data=aInImageName)
        logger.debug(
            'image download without docker creds status return code and message' + str(r.status_code) + " " + str(
                r.json()))


def updateImages():
    global TenantID
    global g_RequiredImages

    if TenantID == 'Empty':
        logger.debug('TenantID has not been set yet')
        return

    logger.debug('updateImages call ...')
    logger.debug(g_RequiredImages)

    lLocalImages = {}
    lDockersImgUrl = 'http://127.0.0.1:4243/images/json'
    r = requests.get(lDockersImgUrl)
    for lLocalImgTags in r.json():
        try:
            for lLocalImg in lLocalImgTags['RepoTags']:
                try:
                    if lLocalImg not in lLocalImages:
                        logger.debug('Exists image name ' + lLocalImg)
                        lLocalImages[lLocalImg] = lLocalImg
                except Exception as e:
                    nfltErr = "Error 1 processing a tag in img: %s " % e
                    logger.error(nfltErr)
                    exc_type, exc_value, exc_traceback = sys.exc_info()
                    el = repr(traceback.format_exception(exc_type, exc_value, exc_traceback))
                    logger.error(nfltErr + el)
        except Exception as e:
                nfltErr = "Error 2 processing images : %s " % e
                logger.error(nfltErr)
                exc_type, exc_value, exc_traceback = sys.exc_info()
                el = repr(traceback.format_exception(exc_type, exc_value, exc_traceback))
                logger.error(nfltErr + el)


    lNeededImages = g_RequiredImages
    if lNeededImages is None:
        lImagesUrl = EngineEndpoint + '/subscriptions/' + TenantID + '/GetImages'
        logger.debug(lImagesUrl)
        r = requests.get(lImagesUrl)
        if r.status_code != requests.codes.ok:
            logger.debug("GET Images call failed ")
            return
        lNeededImages = r.json()
        logger.debug("updateImages: Required Images has been retrieved from master pull")
    else:
        logger.debug("updateImages: Required Images has been set from master api")

    for lImage in lNeededImages:
        logger.debug('Required Image Name ' + lImage)
        # lRequiredRepo = lImage.split(":")[0]
        if lImage in lLocalImages:
            logger.debug('Required image exists ' + lImage)
        else:
            logger.debug('++++++++++ Need to download Image ' + lImage)
            try:
                downloadImage(lImage)
            except Exception as e:
                nfltErr = "Error 3 The download error was : %s " % e
                logger.error( nfltErr)
                exc_type, exc_value, exc_traceback = sys.exc_info()
                el = repr(traceback.format_exception(exc_type, exc_value, exc_traceback))
                logger.error(nfltErr + el)


def pruneImages():
    try:
        logger.debug('Start pruning images')
        client = docker.from_env()
        filters = {'dangling': '0'}
        client.images.prune(filters)
        logger.debug('Finished pruning')
    except Exception as e:
        nfltErr = "Error 4 pruning images 10 : %s " % e
        logger.error( nfltErr)
        exc_type, exc_value, exc_traceback = sys.exc_info()
        el = repr(traceback.format_exception(exc_type, exc_value, exc_traceback))
        logger.error(nfltErr + el)


def updateImagesThread():
    lCount = 0
    while (True):
        time.sleep(12)

        try:
            lCount = lCount + 1
            if lCount >= 7200:
                pruneImages()
                lCount = 0
        except  Exception as e:
            nfltErr = "Error 5 pruning images : %s " % e
            logger.error( nfltErr)
            exc_type, exc_value, exc_traceback = sys.exc_info()
            el = repr(traceback.format_exception(exc_type, exc_value, exc_traceback))
            logger.error(nfltErr + el)

        try:
            updateImages()
        except  Exception as e:
            nfltErr = "Error 6 pruning images : %s" % e
            logger.error(nfltErr + nfltErr)
            exc_type, exc_value, exc_traceback = sys.exc_info()
            el = repr(traceback.format_exception(exc_type, exc_value, exc_traceback))
            logger.error(nfltErr+ el)
        logger.debug('=============================================== UpdateImages Completed')


def getOptions():
    name = None

    parser = argparse.ArgumentParser(description='Network Agent ')
    parser.add_argument('-m', '--mode',
                        help='Network Agent overlay mode',
                        type=str, default='gre')

    args = vars(parser.parse_args())

    lmode = args.get('mode', 'gre')

    return lmode


def setLogger():
    logFile = "/var/log/NetworkAgent.log"
    logger = logging.getLogger('NetworkAgent')

    fh = handlers.RotatingFileHandler(logFile, maxBytes=5000000, backupCount=5)
    logFormat = Formatter('%(asctime)s %(levelname)s %(message)s')
    fh.setFormatter(logFormat)

    logger.addHandler(fh)
    logger.setLevel(logging.DEBUG)

    # fh = logging.FileHandler("/var/log/NetworkAgent.log", "w")
    # fh.setLevel(logging.DEBUG)
    # logger.addHandler(fh)

    #
    # Detach stdout, stdin and stderr for daemonizing
    #
    f = open('/dev/null', 'w')
    sys.stdout = f
    sys.stderr = f
    sys.stdin.close()

    logger.debug('stdout/stderr redirected to /dev/null ...')

    return logger



def daemonizeUbuntu():

    process_id = os.getpid()
    logger.debug('Process ID after setid(): %s...' % str(process_id))

    pidfile = open('/var/run/NetworkAgent.pid', 'w')
    pidfile.write("%d" % process_id)
    pidfile.close()

    # Set umask to default to safe file permissions when running
    # as a root daemon. 027 is an octal number.
    os.umask(0o27)

    # Change to a known directory.  If this isn't done, starting
    # a daemon in a subdirectory that needs to be deleted results
    # in "directory busy" errors.
    # On some systems, running with chdir("/") is not allowed,
    # so this should be settable by the user of this library.
    os.chdir('/')

    logger.debug('Daemonization complete')


def getLinuxDistro():
    # dist = platform.dist()
    # return dist[0]
    return "Ubuntu"


def main():
    global logger
    logger = setLogger()

    lmode = getOptions()

    if lmode == "udp":
        global g_udpmode
        g_udpmode = True
        logger.debug('Network Agent in UDP Mode')
    else:
        logger.debug('Network Agent in GRE mode')

    linuxDistro = getLinuxDistro()
    logger.debug('Create Daemon on %s' % linuxDistro)

    #
    # Method to start daemon varies on different linux
    # distro. Get the linux distro and daemonize as appropriate
    #
    # on ubunut: use upstart
    #   * copy NeworkAgent.conf to /etc/init
    #   * Create defaults in /etc/default
    #   * start daemon using 'sudo start daemon'
    #

    if linuxDistro == 'Ubuntu':
        logger.debug('Create Daemon on %s' % linuxDistro)
        daemonizeUbuntu()
    else:
        logger.debug('Daemon on Linux Distro %s is not supported...' % linuxDistro)

    logger.debug('Launching Image update Thread')
    lImagesthrd = Thread(target=updateImagesThread, args=[])
    lImagesthrd.setDaemon(True)
    lImagesthrd.start()

    app.run(host='0.0.0.0', port=60035, debug=True, use_reloader=False)


if __name__ == '__main__':
    main()

