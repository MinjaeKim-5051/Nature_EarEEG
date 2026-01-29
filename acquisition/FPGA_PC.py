# ==================================================
# Python Host Interface (PC - FPGA)
# ==================================================

# ==================================================
# Open FPGA connection
# --------------------------------------------------
# Import ok (host interface API)
import sys
API_directory = "C:\\Program Files\\Opal Kelly\\FrontPanelUSB\\API\\Python\\x64"
sys.path.insert(0, API_directory) # ok 파일 위치를 경로에 추가

import os
import ok
import time
import struct # PC2FPGA_pipe, FPGA2PC
# ==================================================

class FPGA():
   # --------------------------------------------------
   # 생성자
   def __init__(self, bit_file_directory):
      self.bit_file_directory = bit_file_directory
      self.directory = os.path.dirname(os.path.realpath(__file__))

      # --------------------------------------------------
      # Try FPGA connection
      self.dev = ok.okCFrontPanel()
      self.dev.OpenBySerial("")
      error = self.dev.ConfigureFPGA(self.bit_file_directory) # bit 파일 위치

      # --------------------------------------------------
      # Connection check
      print("\nerror code: ", end = "")
      if(error == 0):
         print(str(error) + " (No error found)")
      else:
         print(error)

      if(self.dev.IsFrontPanelEnabled()):
         print("FrontPanel host interface enabled.")
      else:
         sys.stderr.write("FrontPanel host interface not detected.\n")
         sys.exit()

      # --------------------------------------------------
      # FPGA 설정 파일 생성
      with open(self.directory+"\\info_FPGA.txt", "w", encoding="utf8") as file_info:
         file_info.write("\n*** FPGA Setting Info ***")
         file_info.write("\n- Connected Bit File  : {0}".format(self.bit_file_directory))
         file_info.write("\n- Info File Directory : {0}".format(self.directory+"\\info_FPGA.txt"))

   # --------------------------------------------------
   # 소멸자
   def __del__(self):
      print("... Cut FPGA Connection")

   # --------------------------------------------------
   # FPGA 설정 파일
   def show_info(self):
      with open(self.directory+"\\info_FPGA.txt", "r", encoding="utf8") as file_info:
         print(file_info.read())

   def update_info(self):
      with open(self.directory+"\\info_FPGA.txt", "w", encoding="utf8") as file_info:
         file_info.write("\n*** FPGA Setting Info ***")
         file_info.write("\n- Connected Bit File  : {0}".format(self.bit_file_directory))
         file_info.write("\n- Info File Directory : {0}".format(self.directory+"\\info_FPGA.txt"))

   # --------------------------------------------------
   # Basic functions (FPGA와 통신)
   def f_wirein(self, addr, val):
      self.dev.SetWireInValue(addr, val)
      self.dev.UpdateWireIns()

   def f_wireout(self, addr):
      self.dev.UpdateWireOuts()
      wireValue = self.dev.GetWireOutValue(addr)
      return wireValue

   def f_triggerin(self, addr, val):
      self.dev.ActivateTriggerIn(addr, val)

   def f_triggerout(self, addr, mask):
      self.dev.UpdateTriggerOuts()
      result = self.dev.IsTriggered(addr, mask)
      return result

   def f_pipein(self, addr, data_buf):
      data_in_error = self.dev.WriteToPipeIn(addr, data_buf)
      if(data_in_error != len(data_buf)):
         print("Error occurred during \"Send data to FPGA\"")
         print("Error Code : {0}".format(data_in_error))
      else:
         # print("No error found during \"Send data to FPGA\"")
         pass

   def f_pipeout(self, addr, data_buf):
      data_out_error = self.dev.ReadFromPipeOut(addr, data_buf)
      if(data_out_error != len(data_buf)):
         print("Error occurred during \"Extract data from FPGA\"")
         print("Error Code : {0}".format(data_out_error))
         return False
      else:
         # print("No error found during \"Extract data from FPGA\"")
         return data_buf
