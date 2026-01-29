# ==================================================
# Python Host Interface (PC <-> FPGA <-> ADC)
# ==================================================
# from my_ADC_magic import * # 사용자 정의 함수들
import getpass # 컴퓨터 사용자 이름 가져오기
import time # 시간관련 함수들
from IC_control import *
from matplotlib import pyplot as plt # plot 용
import numpy as np # plot 용 array 생성
from scipy import signal
from matplotlib.animation import FuncAnimation
from functools import partial

# ==================================================
# A. Set FPGA connection
# --------------------------------------------------
user_name = getpass.getuser()
bit_file_directory = "C:\\Users\\mjkim\\vscode_result_3\\vivado\\earEEG_IC_2021_3\\earEEG_IC_2021_3.runs\\impl_1\\earEEG_prototype_top.bit"
print(bit_file_directory)
save_folder = "C:\\Users\\mjkim\\vscode_result_3\\earEEG_prototype_test\\result"
my_device = IC_control(bit_file_directory,save_folder)

my_device.debug0 = 0
my_device.debug1 = 0
my_device.FPGA.f_wirein(0x02, (my_device.debug1*16 + my_device.debug0))

my_device.previn_code = "00000111"


for idx_whole in range(1):

   fs_in = "5"
   # fs_in = str(idx_whole + 3)
   my_device.debug1 = int(fs_in)
   my_device.FPGA.f_wirein(0x02, (my_device.debug1*16 + my_device.debug0))

   gate4 = "0000"
   my_device.cont1 = gate4[0]
   my_device.cont2 = gate4[1]
   my_device.cont3 = gate4[2]

   ## output
   n_data = 64000*120
   my_device.ADC_start(n_data)

   # fig, axes = plt.subplots(nrows=1, ncols=1, sharex=True, sharey=False)

   # def update(n_data):
   #    n_data = 64000*0.01
   #    my_device.ADC_start(n_data)

   # ani = FuncAnimation(fig, update, frames=1, interval=0)
   # plt.show()
   #print(my_device.FPGA.f_wireout(0x21))
# ==================================================
