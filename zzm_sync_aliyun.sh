#!/bin/bash
set -euo pipefail  # 启用更严格的错误处理

# 配置信息
TARGET_REGISTRY="crpi-5poygbapvay5ix9x.cn-hangzhou.personal.cr.aliyuncs.com"
TARGET_NAMESPACE="libzzm-ubuntu22"
CONFIG_FILE="zzm_sync_aliyun.conf"

# 检查配置文件是否存在
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "错误: 配置文件 '$CONFIG_FILE' 不存在" >&2
    exit 1
fi

# 读取配置文件中的镜像列表
# 过滤掉空行和注释行
readarray -t IMAGES < <(grep -Ev '^\s*(#|$)' "$CONFIG_FILE")

# 检查是否有镜像需要处理
if [[ ${#IMAGES[@]} -eq 0 ]]; then
    echo "错误: 配置文件中没有找到有效的镜像" >&2
    exit 1
fi

# 登录到目标镜像仓库
echo "正在登录到镜像仓库 $TARGET_REGISTRY..."
docker login "$TARGET_REGISTRY" || {
    echo "错误: 登录失败" >&2
    exit 1
}

# 处理每个镜像
for image in "${IMAGES[@]}"; do
    echo -e "\n===== 处理镜像: $image ====="
    
    # 检查镜像格式是否正确
    if [[ ! "$image" =~ ^[^/]+/[^:]+:[^:]+$ ]]; then
        echo "警告: 镜像 '$image' 格式不正确，跳过" >&2
        continue
    fi
    
    # 拉取镜像
    echo "拉取镜像..."
    if ! docker pull "$image"; then
        echo "错误: 拉取镜像失败，跳过" >&2
        continue
    fi
    
    # 提取镜像名称和标签 (使用更健壮的解析方法)
    repo="${image%/*}"
    name_with_tag="${image##*/}"
    name="${name_with_tag%:*}"
    tag="${name_with_tag#*:}"
    
    # 构建目标镜像完整名称
    target_image="${TARGET_REGISTRY}/${TARGET_NAMESPACE}/${name}:${tag}"
    
    # 打标签
    echo "创建标签: $target_image"
    docker tag "$image" "$target_image"
    
    # 推送镜像
    echo "推送镜像到仓库..."
    if docker push "$target_image"; then
        echo "成功推送: $target_image"
    else
        echo "错误: 推送失败" >&2
    fi
    
    # 清理临时标签 (可选)
    docker rmi "$target_image" 2>/dev/null || true
done

echo -e "\n===== 所有镜像处理完成 ====="
