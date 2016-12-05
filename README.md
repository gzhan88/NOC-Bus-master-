# NOC Bus master
This module adds bus master capabilities to the NOC interface. 

## Overview of NOC Bus master design
This bus master will not modify the CRC, but modify the NOC. The Bus Master NOC connected CRC engine expands on the existing CRC design. This project is to enhance the NOC controller, (Not the CRC block) to be a bus master. The bus master logic will use the NOC interface to fetch and store data to a memory. This memory is in the test bench.

* Detailed description: Please go through the attached bus master document "BM_NOC.pdf" for the complete design specification of the Bus masetr block for NOC controller.

* The commands used are specific to the Synopsys tool (VCS tool for simulation and design compiler for synthesis) and might not run on other tool.

* The sv_uvm script will run the simulator. Use command "./sv_uvm tbbm.sv" to run bus master simulation.
