#version 450 core
#define PRECISION $precision
#define FORMAT $format

layout(std430) buffer;

/*
 * Output Image
 */
layout(set = 0, binding = 0, FORMAT) uniform PRECISION image3D uOutput;

/*
 * Input Textures
 */
layout(set = 0, binding = 1) uniform PRECISION sampler3D uInput;

/*
 * Params Buffer
 */
layout(set = 0, binding = 2) uniform PRECISION restrict Block {
  // output texture size (x=width,y=height,z=depth,w=unused)
  ivec4 out_extents;
  // input texture size (x=width,y=height,z=depth,w=unused)
  ivec4 in_extents;
  // input tensor's batch size
  uint batch_size;
  // input tensor's channel size
  uint ch_size;
  // total number of channels in the output tensor
  uint ch_total;
  // number of channels already appended
  uint ch_current;
}
uBlock;

/*
 * Local Work Group
 */
layout(local_size_x_id = 0, local_size_y_id = 1, local_size_z_id = 2) in;

void main() {
  const ivec3 in_pos = ivec3(gl_GlobalInvocationID);

  if (any(greaterThanEqual(in_pos, uBlock.in_extents.xyz))) {
    return;
  }

  // x and y don't change. only z and index matter
  ivec3 out_pos = in_pos;
  const vec4 in_tex = texelFetch(uInput, in_pos, 0);

  for (uint i = 0; i < 4; ++i) {
    uint src_nc_idx = in_pos.z * 4 + i;
    uint src_n_idx = src_nc_idx / uBlock.ch_size;
    uint src_c_idx = src_nc_idx % uBlock.ch_size;

    if (src_c_idx >= uBlock.ch_size) {
      // out of range
      break;
    }

    uint dst_c_idx = src_c_idx + uBlock.ch_current;
    uint dst_nc_idx = src_n_idx * uBlock.ch_total + dst_c_idx;

    out_pos.z = int(dst_nc_idx / 4);
    uint j = (dst_nc_idx % 4);

    vec4 out_tex = imageLoad(uOutput, out_pos);
    out_tex[j] = in_tex[i];
    imageStore(uOutput, out_pos, out_tex);
  }
}
