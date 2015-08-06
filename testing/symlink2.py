import os

def dirs(MyDir):
  if os.path.isdir(MyDir):
    for f in os.listdir(MyDir):
      kaosname = os.path.join(MyDir,f)
      if os.path.isdir(kaosname):
        dirs(kaosname)
      else:
        if os.path.isfile(kaosname):
          ext = os.path.splitext(f)[1]
          if  ext == ".mp4":
            print kaosname
            kalname = os.path.join("/media/RACHEL/kacontent",f)
            if os.path.exists(kalname):
              if os.path.islink(kalname):
                os.unlink(kalname)
                os.rename(kaosname,kalname)
                os.chmod(kalname, 0755)
              elif os.path.isfile(kalname):
                os.unlink(kaosname)
            else:
              os.rename(kaosname,kalname)
            os.symlink(kalname,kaosname)
            os.chmod(kaosname, 0755)
            print kalname
  return

if __name__ == "__main__":
  import sys
  if len(sys.argv) > 1:
    dirs(sys.argv[1])
  else:
    dirs("/media/RACHEL/rachel/modules/kaos-en")
