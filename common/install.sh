UNSELECTED_MODE=-1
SELINUX_MODE=$UNSELECTED_MODE

$ZIP_FILE = $(basename $ZIP)
case $ZIP_FILE in
  *permissive*|*Permissive*|*PERMISSIVE*)
    SELINUX_MODE=0
    ;;
  *enforc*|*Enforc*|*ENFORC*)
    SELINUX_MODE=1
    ;;
esac

# 将此路径更改为keycheck二进制文件在安装程序中的位置
KEYCHECK=$INSTALLER/keycheck
chmod 755 $KEYCHECK

keytest() {
  ui_print "- 音量键测试 -"
  ui_print "   按下音量+:"
  (/system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > $INSTALLER/events) || return 1
  return 0
}   

choose() {
  #来自 chainfire @xda-developers 的说明: getevent behaves weird when piped, and busybox grep likes that even less than toolbox/toybox grep
  while (true); do
    /system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > $INSTALLER/events
    if (`cat $INSTALLER/events 2>/dev/null | /system/bin/grep VOLUME >/dev/null`); then
      break
    fi
  done
  if (`cat $INSTALLER/events 2>/dev/null | /system/bin/grep VOLUMEUP >/dev/null`); then
    return 0
  else
    return 1
  fi
}

chooseold() {
  # Calling it first time detects previous input. Calling it second time will do what we want
  $KEYCHECK
  $KEYCHECK
  SEL=$?
  if [ "$1" == "UP" ]; then
    UP=$SEL
  elif [ "$1" == "DOWN" ]; then
    DOWN=$SEL
  elif [ $SEL -eq $UP ]; then
    return 0
  elif [ $SEL -eq $DOWN ]; then
    return 1
  else
    ui_print "   未检测到音量键!"
    abort "   在TWRP中使用更改名称方法安装"
  fi
}

if [ $SELINUX_MODE == $UNSELECTED_MODE ]; then
  if keytest; then
    FUNCTION=choose
  else
    FUNCTION=chooseold
    ui_print "   ! 检测到旧设备！使用旧的keycheck方法"
    ui_print " "
    ui_print "- 音量键编程中 -"
    ui_print "   再次按下音量+:"
    $FUNCTION "UP"
    ui_print "   按下音量-"
    $FUNCTION "DOWN"
  fi
  
  ui_print " "
  ui_print "---选择SELinux模式---"
  ui_print "  音量+ = 执行(Enforcing)"
  ui_print "  音量- = 许可(Permissive)"
  if $FUNCTION; then
    SELINUX_MODE=1
    ui_print "已选择SELinux模式 执行(Enforcing)."
  else
    SELINUX_MODE=0
    ui_print "已选择SELinux模式 许可(Permissive)."
  fi
else
  ui_print "在文件名中指定SELinux模式 : $ZIP_FILE"
fi

ui_print "将SELinux模式写入启动脚本中..."
sed -i "s/<SELINUX_MODE>/$SELINUX_MODE/g" $INSTALLER/common/post-fs-data.sh
