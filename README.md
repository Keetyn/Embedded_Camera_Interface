# Upduino 3.1 HIMAX shield Camera interface

## Overview
This repository contains the necessary verilog files, matlab program, and constraints files
to enable the collection of images from the HM01B0 sensor on the HIMAX 
shield using an UPduino 3.1. This code was developed using APIO and as such the constraints files are intended for use with APIO.

## File structure breakdown
The topmost src file contains two main directories:
1. RTL Folder - The RTL folder contains all of the source verilog files, as well as directories for the testbenches and constraints files.
2. Software Folder - The software folder contains the MATLAB app that can be run to collect and display images from the FPGA board using a UART interface
