def debug():
   print("Debug")
   while True:
      try:
         command = input('>>')
         if (command == "break"):
            break
         exec(command)
      except Exception as e:
         print(e)

def show_info():
   from os import path, chdir
   directory = path.dirname(path.realpath(__file__))
   chdir(directory)
   with open("info.txt", "r", encoding="utf8") as file_info:
      print(file_info.read())

def to_binary(num,bit): # two's complement
   if (num <= (2**(bit-1)-1) and num >= -(2**(bit-1))):
      if num < 0:
         b_num = bin(num & int("1"*bit, 2))[2:]
      else:
         b_num = ("{0:0%sb}"% (bit)).format(num)
      return b_num
   else:
      print("num overflows disignated bit")
