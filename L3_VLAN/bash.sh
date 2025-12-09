#!/bin/bash 

# Initializing Config Variables
VLAN_A_ID=10
VLAN_B_ID=20

VLAN_A_GW="10.0.0.1"
VLAN_B_GW="10.0.1.1"

VLAN_A_PC_IP="10.0.0.2/24"
VLAN_B_PC_IP="10.0.1.2/24"

cleanup(){
    echo "1. Cleanup of previous configuration in progress"
    sudo sysctl -w net.ipv4.ip_forward=0 > /dev/null

    sudo ip link delete br0.$VLAN_A_ID 2>/dev/null
    sudo ip link delete br0.$VLAN_B_ID 2>/dev/null

    sudo ip link delete br0 2>/dev/null

    sudo ip netns delete vlan1_pc 2>/dev/null
    sudo ip netns delete vlan2_pc 2>/dev/null

    echo "Cleanup is complete"
}

setup(){
    # Virtual Equipment Setup
    echo "2. Setting up the namespaces and the bridge"

    # Two isolated rooms(computers) are created
    sudo ip netns add vlan1_pc
    sudo ip netns add vlan2_pc

    # Creating the L2 switch/bridge/elevator messenger
    sudo ip link add name br0 type bridge

    # Enable it to allow VLAN spltting
    sudo ip link set br0 type bridge vlan_filtering 1
    sudo ip link set br0 up

    # Create cables that will connect the computers
    #to the router/bridge
    sudo ip link add vethA type veth peer name vethA-br
    sudo ip link add vethB type veth peer name vethB-br

    # Connect the bridge end of the cable to the bridge
    sudo ip link set vethA-br master br0
    sudo ip link set vethB-br master br0

    # Label the cables: "vethA-br is for accessing Floor 10"
    # "vethB-br is for accessing Floor 20"
    sudo bridge vlan add vid $VLAN_A_ID dev vethA-br pvid untagged
    sudo bridge vlan add vid $VLAN_B_ID dev vethB-br pvid untagged

    # Turn on the cables
    sudo ip link set vethA-br up
    sudo ip link set vethB-br up

    # Connect the computer end of the cables to the computers
    sudo ip link set vethA netns vlan1_pc
    sudo ip link set vethB netns vlan2_pc

    
    # Layer 2 VLAN Setup
    echo "3. Configuring up Layer 2 VLANs (Aceess Ports)"

    # This assigns the computers with IP addresses
    sudo ip netns exec vlan1_pc ip addr add $VLAN_A_PC_IP dev vethA
    sudo ip netns exec vlan1_pc ip link set vethA up
    sudo ip netns exec vlan1_pc ip link set lo up

    sudo ip netns exec vlan2_pc ip addr add $VLAN_B_PC_IP dev vethB
    sudo ip netns exec vlan2_pc ip link set vethB up
    sudo ip netns exec vlan2_pc ip link set lo up


    echo "4. L3 Implementation: Configuring VLAN subinterfaces to allow 
    connectivity between VLANs"

    # This is like adding doors to allow entrances to these specific
    #VLANs
    sudo ip link add link br0 name br0.$VLAN_A_ID type vlan id $VLAN_A_ID
    sudo ip link add link br0 name br0.$VLAN_B_ID type vlan id $VLAN_B_ID

    #Allow the bridge master interface (br0)
    # to receive traffic tagged with VLAN 10 and VLAN 20.
    sudo bridge vlan add vid $VLAN_A_ID dev br0 self
    sudo bridge vlan add vid $VLAN_B_ID dev br0 self

    sudo ip link set br0.$VLAN_A_ID up
    sudo ip link set br0.$VLAN_B_ID up

    #  Assign the bridge/router's address on each VLAN 
    # (one address per floor)
    sudo ip addr add $VLAN_A_GW/24 dev br0.$VLAN_A_ID
    sudo ip addr add $VLAN_B_GW/24 dev br0.$VLAN_B_ID

    # Enable routing
    sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
    
    # Assign to each computer a specific route to follow
    sudo ip netns exec vlan1_pc ip route add default via $VLAN_A_GW
    sudo ip netns exec vlan2_pc ip route add default via $VLAN_B_GW

    echo "Setup Complete"
}


test_connectivity() {
    echo "5. Testing Connectivity"

    echo "Testing PC (VLAN 10) -> Gateway..."
    sudo ip netns exec vlan1_pc ping -c 3 $VLAN_A_GW

    echo "Testing Inter-VLAN Routing: PC (VLAN 10) -> PC (VLAN 20: )..."
    sudo ip netns exec vlan1_pc ping -c 3 10.0.1.2
    
    echo "Testing Inter-VLAN Routing: PC (VLAN 20) -> PC (VLAN 10: )..."
    sudo ip netns exec vlan2_pc ping -c 3 10.0.0.2
}

case "$1" in
    clean)
        cleanup
        ;;
    test)
        test_connectivity
        ;;
    *)
        cleanup
        setup
        test_connectivity
        ;;
esac