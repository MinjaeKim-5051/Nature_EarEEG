# ==================================================
import os
import getpass # 컴퓨터 사용자 이름 가져오기
import time
import datetime
import sys
import keyboard # 프로그램 실행중 임의시간에 keyboard 입력으로 조정
from matplotlib import pyplot as plt # plot 용
import numpy as np # plot 용 array 생성\
import FPGA_PC as FPGA

import struct
from scipy import signal
from matplotlib.animation import FuncAnimation
from functools import partial


# import random # debug
class IC_control():
   # ==================================================
   # 생성자
   def __init__(self, bit_file_directory, save_folder):
      # --------------------------------------------------
      # Make FPGA controller
      if __name__ == "__main__":
         import FPGA_PC
      self.FPGA = FPGA.FPGA(bit_file_directory)

      # --------------------------------------------------
      # 변수 설정
      self.bit_file_directory = bit_file_directory
      self.directory = os.path.dirname(os.path.realpath(__file__))
      self.user_name = getpass.getuser()
      
      self.previn_code = "00000111" # BUFCON, fch_SEL, NDR, FREEZE, OVER, EXT_STAYB, EXT_RES, EXT_D

      self.cont1 = 0 # PREVIN gate
      self.cont2 = 0 # ADC gate
      self.cont3 = 0 # output gate

      self.save_folder = save_folder
      self.file_set = set() # result_file list
      self.idx_file_num = 0

      self.debug0 = 0 # debug control
      self.debug1 = 0 # debug control
      
      self.FPGA.f_wirein(0x03, int(65535))

   # ==================================================
   # 소멸자
   def __del__(self):
      print("... Delete ADC controller")

   # ==================================================
   # Basic functions
   # --------------------------------------------------
   # Config 파일
   def update_info(self):
      with open(self.directory+"\\info_IC_control.txt", "w", encoding="utf8") as file_info:
         file_info.write("\n*** IC Setting Info ***\n")
         file_info.write("\n- Connected Bit File  : {0}".format(self.bit_file_directory))
         file_info.write("\n- Info File Directory : {0}".format(self.directory+"\\info_IC_control.txt"))
         file_info.write("\n- PREVIN_set : {0}\n".format(self.previn_code))

         file_info.write("\n- PREVIN     : {0}".format(bool(self.cont1)))
         file_info.write("\n- ADC  : {0}".format(bool(self.cont2)))
         file_info.write("\n- output     : {0}\n".format(bool(self.cont3)))

         file_info.write("\n- Debug pin #0 : {0}".format(self.debug0))
         file_info.write("\n- Debug pin #1 : {0}\n".format(self.debug1))
         
         file_info.write("\n- result file list : {0}".format(self.file_set))
   
   def show_info(self):
      self.update_info()
      with open(self.directory+"\\info_IC_control.txt", "r", encoding="utf8") as file_info:
         print(file_info.read())
   
   # --------------------------------------------------
   # 결과 파일
   def result_folder_maker(self):
      # Make log_file folder
      try:
         # Make log_file folder
         os.mkdir(self.save_folder)

         # Print message and change variable
         print("\nProgram succeed to make result folder\n")
         time.sleep(1)

      except Exception as err:
         # Print error message
         print("\nProgram fails to make result_log folder")
         print(err)
         time.sleep(1) # wait 1sec

   def result_file_maker(self,file_addr,file_name,file_num):
      if (not ((file_name,file_num) in self.file_set)): # No result_file exists
         try:
            # Create result_file
            self.file_set.add((file_name,file_num))
            f_result_file = open(file_addr+"\\"+file_name+str(file_num)+".csv",'w')

            # Print message and change variable
            print("\n"+file_name+str(file_num)+".csv"+" is created\n")
            return f_result_file
         except Exception as err:
            print("\nProgram fails to make "+file_name+str(file_num)+".csv\n")
            print(err)
            return False
         
      else: # Log_files already exists
         try:
            # Print message
            print("\n"+file_name+str(file_num)+".csv"+" already exist\n")
            # Open log_files
            f_result_file = open(file_addr+"\\"+file_name+str(file_num)+".csv",'a')
            return f_result_file
         except Exception as err:
            print("\nProgram fails to open "+file_name+str(file_num)+".csv\n")
            print(err)
            return False

   # --------------------------------------------------
   # Main functions
   def reset(self):

      ### Reset
      # Reset ON, trigger bit 중 0번 bit 활성화 (for 1 CLK)
      self.FPGA.f_triggerin(0x40, 0)
      time.sleep(0.01) # wait 250ms
      print(".", end = "")

      # Reset OFF, trigger bit 중 0번 bit 활성화 (for 1 CLK)
      self.FPGA.f_triggerin(0x40, 0)
      time.sleep(0.01) # wait 250ms
      print(".", end = "")

      ### PREVIN
      # 설정값 유지
      self.FPGA.f_wirein(0x00, int((self.previn_code),2))
      time.sleep(0.25) # wait 250ms
      print(".", end = "")

      # Previn trigger, trigger bit 중 1번 bit 활성화 (for 1 CLK)
      self.FPGA.f_triggerin(0x40, 1)
      time.sleep(0.25) # wait 250ms
      print(".", end = "")
      print("Reset is completed")

   def initiaize(self):
      # 설정값 초기화
      self.previn = "00000111" # BUFCON, fch_SEL, NDR, FREEZE, OVER, EXT_STAYB, EXT_RES, EXT_D

      self.cont1 = 0 # PREVIN gate
      self.cont2 = 0 # ADC gate
      self.cont3 = 0 # output gate

      # Reset
      print("\nInitialization")
      self.reset()
      print("Initialization is completed")

   def recover(self, dataIn):
      dat_len = len(dataIn)
      dataOut = np.zeros(dat_len)
      scMat = np.zeros(dat_len)
      minScale = 2**(-12)
      maxScale = 2**(-5)
      #VREF = 0.806;
      VREF = 1

      # vectorize each channel
      dataCh = [int(i) for i in dataIn]
      
      # initialization
      y = np.zeros(5)
      y[4] = 1
      y[2] = 1
      scale = minScale
      delta_return = np.zeros(dat_len)
      
      for inner in range(dat_len-1): # inner: time
         # shift the histories out
         y[1:] = y[:-1]
         y[0] = round(dataCh[inner])
         # now do a check on the histories and update scale;
         
         # if all the Y's are the same
         if np.all(y == y[0]):
               scale *= 2
         #if all the three y's are not the same
         elif (y[0] != y[1]) and (y[1] != y[2]):
               scale /= 2
         if scale > maxScale:
               scale = maxScale
         elif scale < minScale:
               scale = minScale
         
         # data value = previous value + (+/-)1* scale;
         delta = np.sign(y[0] - 0.5) * scale * 2 * VREF
         delta_return[inner] = delta

         temp = dataOut[inner] + delta
         if temp >= 1: #VREF
               dataOut[inner+1] = dataOut[inner]
         elif temp < -1: # VREF
               dataOut[inner+1] = dataOut[inner]
         else:
               dataOut[inner+1] = temp
         
         scMat[inner+1] = scale
      
      return dataOut, scMat, delta_return
   
   def ADC_start(self, n_data):
      # log_file 만들기
      self.result_folder_maker()
      f_log_NOUT = self.result_file_maker(self.save_folder,"NOUT",self.idx_file_num)
      self.idx_file_num += 1 # increase output_log_file number

      # ADC data read
      print("\nStart reading process\n")
      self.reset()

      # num_toread = int(input("# of data points to read >>> "))
      num_toread = int(n_data)
      num_read = 0

      ### Variable setting
      time_dec = [] # 수행시간 확인용
      tt = time.time() # 수행시간 확인용
         
      ### Read data from FPGA (ADC data 포함)
      # f_log_NOUT.write("ch-1,ch-2,ch-3,ch-4\n")
      self.FPGA.f_triggerin(0x40, 3) # FIFO 시작 trigger
         
      data_buf_NOUT = bytearray(262114)

      DOUT = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]


      while (num_read < num_toread):
         # NEXTOUT (데이터 개수 세는 기준)
         num_fifo_NOUT = self.FPGA.f_wireout(0x20) # 읽을 수 있는 데이터 수 (FIFO에 저장된 데이터 수), if 65535 == overflow
         print(num_fifo_NOUT)

         num_fifo_read_NOUT = num_fifo_NOUT//1 # USB 2.0 통신단위 = 2byte = 16bit = 1 FIFO out = 0.5 Data
         numBytes_NOUT = num_fifo_read_NOUT * 2
         # print(numBytes_NOUT)

         if (numBytes_NOUT > 0):
            data_buf_NOUT[0:numBytes_NOUT] = self.FPGA.f_pipeout(0xA0,data_buf_NOUT[0:numBytes_NOUT])
            # print(self.FPGA.f_wireout(0x21))
            # for idx_data_out in range(min(numBytes_NOUT,(num_toread - num_read))):
            for idx_data_out in range(min(num_fifo_read_NOUT,(num_toread - num_read))):
               data_NOUT = int.from_bytes(data_buf_NOUT[(2*(idx_data_out)):
                                             (2*(idx_data_out)+2)],
                                          byteorder='big') # 2byte = 16bit씩 추출
               aaa = ("{0:0%sb}"%(16)).format(data_NOUT)
               
               # NEXTOUT
               f_log_NOUT.write(aaa[0]+",")
               f_log_NOUT.write(aaa[1]+",")
               f_log_NOUT.write(aaa[2]+",")
               f_log_NOUT.write(aaa[3]+",")
               f_log_NOUT.write(aaa[4]+",")
               f_log_NOUT.write(aaa[5]+",")
               f_log_NOUT.write(aaa[6]+",")
               f_log_NOUT.write(aaa[7]+",")
               f_log_NOUT.write(aaa[8]+",")
               f_log_NOUT.write(aaa[9]+",")
               f_log_NOUT.write(aaa[10]+",")
               f_log_NOUT.write(aaa[11]+",")
               f_log_NOUT.write(aaa[12]+",")
               f_log_NOUT.write(aaa[13]+",")
               f_log_NOUT.write(aaa[14]+",")
               f_log_NOUT.write(aaa[15]+"\n")

               for i in [2,6,10,14]:
                  DOUT[i].append(aaa[i]) # DOUT은 DOUT bitstream

         num_read += num_fifo_read_NOUT
         tt1 = time.time()
         time_dec.append(tt1-tt)
         tt = tt1

      print("done")
      self.FPGA.f_triggerin(0x40, 3)

      # # filtering
      # f_sam = 63770
      # self.notch_60_b, self.notch_60_a    = signal.butter(2,[55,65],  btype='bandstop',output='ba',fs=int(f_sam))
      # self.low_50_b, self.low_50_a        = signal.butter(4, 50,  btype='lowpass',output='ba',fs=int(f_sam))
      
      # self.all_filt_b = [self.notch_60_b, self.notch_60_b, self.low_50_b]
      # self.all_filt_a = [self.notch_60_a, self.notch_60_a, self.low_50_a]
   
      # global zi1
      # global zi2
      # global zi3
      # global data_filt_list
      # data_filt_list = [[],[],[],[]]
      # zi1 = None
      # zi2 = None
      # zi3 = None

      # RECOVERED = []

      # for i in [2,6,10,14]:
      #    temp1, temp2, temp3 = self.recover(''.join(DOUT[i]))
      #    RECOVERED.append(temp1) # Recovered는 복원된 값


      # for j in range (0,4):
      #    length_data = len(RECOVERED[j])
      #    for i in range(0,length_data):
      #       if zi1 is None:
      #          z1 = signal.lfilter_zi(self.all_filt_b[0], self.all_filt_a[0]) * RECOVERED[j][i]
      #          data_filt, zi1 = signal.lfilter(self.all_filt_b[0], self.all_filt_a[0], [RECOVERED[j][i]], zi = z1)
      #          z2 = signal.lfilter_zi(self.all_filt_b[1], self.all_filt_a[1]) * RECOVERED[j][i]
      #          data_filt, zi2 = signal.lfilter(self.all_filt_b[1], self.all_filt_a[1], data_filt, zi = z2)
      #          z3 = signal.lfilter_zi(self.all_filt_b[2], self.all_filt_a[2]) * RECOVERED[j][i]
      #          data_filt, zi3 = signal.lfilter(self.all_filt_b[2], self.all_filt_a[2], data_filt, zi = z3)
      #       else:
      #          data_filt, zi1 = signal.lfilter(self.all_filt_b[0], self.all_filt_a[0], [RECOVERED[j][i]], zi = zi1)
      #          data_filt, zi2 = signal.lfilter(self.all_filt_b[1], self.all_filt_a[1], data_filt, zi = zi2)
      #          data_filt, zi3 = signal.lfilter(self.all_filt_b[2], self.all_filt_a[2], data_filt, zi = zi3)

      #       data_filt_list[j].append(data_filt)


      # Ts = 1/f_sam
      # Nsamp = [RECOVERED[0].size,RECOVERED[1].size,RECOVERED[2].size,RECOVERED[3].size]
      # xFreq = [np.fft.rfftfreq(Nsamp[0],Ts)[:-1],np.fft.rfftfreq(Nsamp[1],Ts)[:-1],\
      #          np.fft.rfftfreq(Nsamp[2],Ts)[:-1],np.fft.rfftfreq(Nsamp[3],Ts)[:-1]]
      # yfft = [(np.fft.rfft(RECOVERED[0])/Nsamp[0])[:-1]*2,(np.fft.rfft(RECOVERED[1])/Nsamp[1])[:-1]*2,\
      #       (np.fft.rfft(RECOVERED[2])/Nsamp[2])[:-1]*2,(np.fft.rfft(RECOVERED[3])/Nsamp[3])[:-1]*2]


      # # plt.figure(1)
      # # plt.subplot(3,1,1)
      # # plt.plot(RECOVERED[0])
      # # plt.gca().set_title('Raw signal, CH1')
      # # plt.subplot(3,1,2)
      # # plt.plot(data_filt_list[0])
      # # plt.gca().set_title('Filtered signal, CH1')
      # # plt.subplot(3,1,3)
      # # plt.semilogx(xFreq[0],20*np.log10(abs(yfft[0])))
      # # plt.gca().set_title('FFT result, CH1')
      # # plt.xlim([0.1,1000])

      # plt.figure(2)
      # plt.subplot(3,1,1)
      # plt.plot(RECOVERED[1])
      # plt.gca().set_title('Raw signal, CH2')
      # plt.subplot(3,1,2)
      # plt.plot(data_filt_list[1])
      # plt.gca().set_title('Filtered signal, CH2')
      # plt.subplot(3,1,3)
      # plt.semilogx(xFreq[1],20*np.log10(abs(yfft[1])))
      # plt.gca().set_title('FFT result, CH2')
      # plt.xlim([0.1,1000])

      # # plt.figure(3)
      # # plt.subplot(3,1,1)
      # # plt.plot(RECOVERED[2])
      # # plt.gca().set_title('Raw signal, CH3')
      # # plt.subplot(3,1,2)
      # # plt.plot(data_filt_list[2])
      # # plt.gca().set_title('Filtered signal, CH3')
      # # plt.subplot(3,1,3)
      # # plt.semilogx(xFreq[2],20*np.log10(abs(yfft[2])))
      # # plt.gca().set_title('FFT result, CH3')
      # # plt.xlim([0.1,1000])

      # plt.figure(4)
      # plt.subplot(3,1,1)
      # plt.plot(RECOVERED[3])
      # plt.gca().set_title('Raw signal, CH4')
      # plt.subplot(3,1,2)
      # plt.plot(data_filt_list[3])
      # plt.gca().set_title('Filtered signal, CH4')
      # plt.subplot(3,1,3)
      # plt.semilogx(xFreq[3],20*np.log10(abs(yfft[3])))
      # plt.gca().set_title('FFT result, CH4')
      # plt.xlim([0.1,1000])

      # plt.figure(5)
      # # plt.plot(data_filt_list[0],label='CH1')
      # plt.plot(data_filt_list[1],label='CH2')
      # # plt.plot(data_filt_list[2],label='CH3')
      # plt.plot(data_filt_list[3],label='CH4')
      # plt.legend()

      # plt.figure(6)
      # # plt.semilogx(xFreq[0],20*np.log10(abs(yfft[0])),label='CH1')
      # plt.semilogx(xFreq[1],20*np.log10(abs(yfft[1])),label='CH2')
      # # plt.semilogx(xFreq[2],20*np.log10(abs(yfft[2])),label='CH3')
      # plt.semilogx(xFreq[3],20*np.log10(abs(yfft[3])),label='CH4')
      # plt.xlim([0.1,1000])
      # plt.ylim([-180,-20])
      # plt.legend()

      # plt.show()


      f_log_NOUT.close()
      print("\nLog files are saved\n")

      # 수행시간 확인용
      with open(self.save_folder + "/log_time_stamp.csv",'w') as f_temp:
         f_temp.write(str(time_dec))
         