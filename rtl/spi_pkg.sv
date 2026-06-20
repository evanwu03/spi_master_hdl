// Author: Evan Wu
// Date: 6/13/2026

`timescale 1ns/1ps

package spi_pkg;

typedef enum logic [1:0] 
{  
    // Uses Gray encoding
    SPI_IDLE = 2'b00,
    SPI_START = 2'b01,
    SPI_DATA = 2'b11

} spi_state_e;



    
endpackage