#!/bin/bash

# 默认参数
fps=10
width=-1
output=""

# 打印使用说明
usage() {
    echo "用法: $0 [选项] 输入文件"
    echo
    echo "选项："
    echo "  -o <输出文件>     指定输出 GIF 文件名称 (默认与输入文件同名)"
    echo "  -w <宽度>          指定 GIF 输出宽度 (默认与输入视频宽度相同)"
    echo "  -f <帧率>          指定 GIF 输出帧率 (默认: 10)"
    echo "  -h                 显示此帮助信息"
    echo
    echo "示例："
    echo "  $0 -o output.gif -w 320 -f 15 input.mp4"
}

# 解析命令行参数
while getopts ":o:w:f:h" opt; do
    case ${opt} in
        o ) # 输出文件名
            output="$OPTARG"
            ;;
        w ) # 宽度
            width="$OPTARG"
            ;;
        f ) # 帧率
            fps="$OPTARG"
            ;;
        h ) # 帮助信息
            usage
            exit 0
            ;;
        \? ) # 处理无效选项
            echo "无效的选项: -$OPTARG" >&2
            usage
            exit 1
            ;;
        : ) # 处理缺少参数的情况
            echo "选项 -$OPTARG 需要一个参数" >&2
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# 检查是否提供了输入文件
if [ $# -eq 0 ]; then
    echo "错误: 必须指定输入文件" >&2
    usage
    exit 1
fi

input_file=$1

# 检查输入文件是否存在
if [ ! -f "$input_file" ]; then
    echo "错误: 输入文件不存在" >&2
    exit 1
fi

# 如果没有指定输出文件，则使用输入文件的名称并将扩展名改为 .gif
if [ -z "$output" ]; then
    output="${input_file%.*}.gif"
fi

# 使用 mktemp 生成临时调色板文件
palette=$(mktemp)

# 生成调色板
ffmpeg -i "$input_file" -vf "fps=$fps,scale=$width:-1:flags=lanczos,palettegen" "$palette"

# 生成 GIF 文件
ffmpeg -i "$input_file" -i "$palette" -filter_complex "fps=$fps,scale=$width:-1:flags=lanczos[x];[x][1:v]paletteuse" "$output"

# 删除临时调色板文件
rm -f "$palette"

echo "GIF 文件已生成: $output"

