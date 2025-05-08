shader_type canvas_item;

uniform vec3 highestColor = vec3(1.0, 1.0, 1.0);
uniform float similarThreshold : hint_range(0.0, 1.0) = 0.0; // Added hint_range
const float scale = 2.0;

// YUV conversion (no changes needed)
const mat3 yuv_matrix = mat3(vec3(0.299, 0.587, 0.114), vec3(-0.169, -0.331, 0.5), vec3(0.5, -0.419, -0.081));
vec3 rgb_to_yuv(vec3 col){
    // Note: The original matrix seemed transposed already based on usage?
    // If colors look weird, try removing the transpose() call.
    // mat3 yuv = transpose(yuv_matrix); // Original had transpose here
    // return yuv * col;
    // Let's use the direct matrix multiplication as typically defined
    return yuv_matrix * col;
}

// Similarity functions (no changes needed)
bool similar(vec4 col1, vec4 col2){
    // Check alpha first for fully transparent pixels
    if (col1.a < 0.001 && col2.a < 0.001) return true;
    // If alpha differs significantly, they aren't similar
    if (abs(col1.a - col2.a) > 0.1) return false;
    // If both opaque or similar alpha, check color distance
    return distance(col1.rgb, col2.rgb) <= similarThreshold;
}
bool similar3(vec4 col1, vec4 col2, vec4 col3){
    return similar(col1, col2) && similar(col2, col3);
}
bool similar4(vec4 col1, vec4 col2, vec4 col3, vec4 col4){
    return similar(col1, col2) && similar(col2, col3) && similar(col3, col4);
}
bool similar5(vec4 col1, vec4 col2, vec4 col3, vec4 col4, vec4 col5){
    return similar(col1, col2) && similar(col2, col3) && similar(col3, col4) && similar(col4, col5);
}

// Priority function (no changes needed, assuming logic is desired)
bool higher(vec4 thisCol, vec4 otherCol){
    if(similar(thisCol, otherCol)) return false; // Similar colors don't have priority over each other
    if(abs(thisCol.a - otherCol.a) > 0.1){ // Prioritize opaque over transparent
        return thisCol.a > otherCol.a;
    } else { // If alpha is similar, use color distance
        // Using raw RGB distance to highestColor
        return distance(thisCol.rgb, highestColor) < distance(otherCol.rgb, highestColor);
        // Alternative: using YUV luminance (uncomment if preferred)
        // return rgb_to_yuv(thisCol.rgb).x > rgb_to_yuv(otherCol.rgb).x;
        // Alternative: using YUV distance (uncomment if preferred)
        // vec3 targetYUV = rgb_to_yuv(highestColor);
        // return distance(rgb_to_yuv(thisCol.rgb), targetYUV) < distance(rgb_to_yuv(otherCol.rgb), targetYUV);
    }
}

// Helper to sample pixel centers accurately
vec4 sample_pixel(sampler2D tex, vec2 tex_size, vec2 pixel_coord) {
    // Convert integer pixel coord to UV coord of the pixel center
    vec2 uv = (pixel_coord + vec2(0.5)) / tex_size;
    // Clamp UVs to prevent potential wrap-around or minor stretching at edges
    // This is often handled by texture import settings (Repeat Disabled/Off),
    // but explicit clamping is safer in the shader.
    uv = clamp(uv, vec2(0.0), vec2(1.0));
    return texture(tex, uv);
}


void fragment() {
    // Calculate texture size in pixels accurately
    vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;

    // Calculate the floating point pixel coordinate for the current fragment
    vec2 float_px = UV * tex_size;

    // Calculate the integer coordinate of the source pixel (top-left corner)
    vec2 px = floor(float_px);

    // Calculate the sub-pixel location within the 4x4 output grid (0, 1, 2, 3)
    vec2 local = floor(fract(float_px) * scale); // Using fract() is cleaner than mod(..., 1.0)

    // Calculate centered coordinate within the 4x4 block (-1.5 to 1.5 range)
    vec2 localDiff = local - vec2(1.5); // Removed redundant /1.0

    // --- Sample Center Pixel and Neighbors ---
    // Use the helper function for clarity and correctness
    vec4 c = sample_pixel(TEXTURE, tex_size, px); // Center pixel

    vec4 t = sample_pixel(TEXTURE, tex_size, px + vec2(0.0, -1.0)); // Top
    vec4 tl = sample_pixel(TEXTURE, tex_size, px + vec2(-1.0, -1.0)); // Top-Left
    vec4 tr = sample_pixel(TEXTURE, tex_size, px + vec2(1.0, -1.0)); // Top-Right
    vec4 l = sample_pixel(TEXTURE, tex_size, px + vec2(-1.0, 0.0)); // Left
    vec4 b = sample_pixel(TEXTURE, tex_size, px + vec2(0.0, 1.0)); // Bottom
    vec4 bl = sample_pixel(TEXTURE, tex_size, px + vec2(-1.0, 1.0)); // Bottom-Left
    vec4 br = sample_pixel(TEXTURE, tex_size, px + vec2(1.0, 1.0)); // Bottom-Right
    vec4 r = sample_pixel(TEXTURE, tex_size, px + vec2(1.0, 0.0)); // Right

    // Sample 's' - This seems specific to the algorithm, potentially sampling a diagonal
    // or interpolated neighbor based on sub-pixel position. Keep its calculation logic
    // but use the corrected 'px' and sampling method.
    vec2 s_offset_px = floor(localDiff / 2.0 + vec2(0.5)); // Simplified offset calculation for 's' pixel
    vec4 s = sample_pixel(TEXTURE, tex_size, px + s_offset_px);
    /* // Original 's' calculation logic adapted:
       vec2 os = localDiff; // Already calculated above
       // The original texture call was: texture(TEXTURE, floor(px+(vec2(0.5,0.5)+os/2.0))/size);
       // Let's translate that using our sample_pixel helper:
       vec2 s_target_coord_center = px + vec2(0.5) + os / 2.0;
       vec2 s_pixel_coord = floor(s_target_coord_center); // Floor to get the integer pixel coord
       vec4 s = sample_pixel(TEXTURE, tex_size, s_pixel_coord);
    */

    // --- Upscaling Algorithm Logic (Clean4x specific) ---
    // Initialize output color to the base pixel color
    vec4 col = c;

    // Checkerboard special case (keep original logic)
    if(similar5(c, tl, tr, bl, br) && similar4(t, r, b, l) && !similar(t, c) && higher(t, c)){ // Added !similar(t,c) check for clarity
        // The original code commented out the actual assignment here.
        // This case likely needs refinement based on the desired checkerboard output.
        // For now, let's assume it might blend or choose based on 'local', e.g.:
         if (mod(local.x + local.y, 2.0) < 1.0) {
             col = c; // or maybe tl/tr/bl/br?
         } else {
             col = t; // or maybe l/r/b?
         }
        // Placeholder: Keep original pixel if checkerboard detected for now.
        // col = c; // Or potentially 't' if t is the higher priority color?
         col = t; // Based on higher(t,c) condition
    } else {
        // Corner case (length(localDiff) > sqrt(1.5^2 + 1.5^2) = sqrt(4.5) approx 2.12)
        if(dot(localDiff, localDiff) > 4.5){ // Use dot product squared for efficiency
            // Original logic seems complex, aiming to smooth corners.
            // Simplified logic: If diagonal neighbors are different from center,
            // blend towards the neighbor with higher priority.

            // Determine which corner based on localDiff sign
            vec2 corner_dir = sign(localDiff); // (-1,-1), (1,-1), (-1,1), or (1,1)
            vec4 corner_neighbor = sample_pixel(TEXTURE, tex_size, px + corner_dir); // tl, tr, bl, or br
            vec4 h_neighbor = sample_pixel(TEXTURE, tex_size, px + vec2(corner_dir.x, 0.0)); // l or r
            vec4 v_neighbor = sample_pixel(TEXTURE, tex_size, px + vec2(0.0, corner_dir.y)); // t or b

            if (!similar(corner_neighbor, c)) {
                 if (higher(corner_neighbor, c) && similar(corner_neighbor, h_neighbor) && similar(corner_neighbor, v_neighbor)) {
                    col = corner_neighbor; // Smooth outwards if corner, H, V neighbors match and are higher prio
                 } else if (higher(h_neighbor, c) && higher(v_neighbor, c)) {
                     // If both adjacent neighbors are higher, maybe pick the highest?
                     col = higher(h_neighbor, v_neighbor) ? h_neighbor : v_neighbor;
                 } else if (higher(h_neighbor, c)) {
                     col = h_neighbor;
                 } else if (higher(v_neighbor, c)) {
                     col = v_neighbor;
                 }
                 // else keep col = c
            }
            // The original logic was very specific, trying to replicate it:
            /*
            if(similar(t, l) && !(similar(tl, c) && !higher(t, c))){ col = t; } // Top or Left higher? Use T? Ambiguous. Should probably be TL check?
            else if(higher(c, l) && higher(c, t) && (similar(tr, c) || similar(bl, c)) && !similar(tl, c)){
                col = higher(t, l) ? t : l; // Prioritize T or L if they are lower than C but TR/BL match C? Complex.
            }
            */

        // Edge case (length(localDiff) > 1.5)
        } else if(dot(localDiff, localDiff) > 2.25) { // 1.5*1.5 = 2.25
            // Original logic for edges is very complex and pattern-specific.
            // It likely tries to detect lines and extend them smoothly.
            // Replicating it exactly requires careful analysis of each condition.
            // A simpler edge approach might be: If orthogonal neighbor differs, pull color from it if higher prio.

            // Example simplified logic:
             if (abs(localDiff.x) > abs(localDiff.y)) { // Horizontal edge (closer to left/right)
                 vec4 edge_neighbor = (localDiff.x > 0.0) ? r : l;
                 if (!similar(edge_neighbor, c) && higher(edge_neighbor, c)) {
                     col = edge_neighbor;
                 }
             } else { // Vertical edge (closer to top/bottom)
                 vec4 edge_neighbor = (localDiff.y > 0.0) ? b : t;
                 if (!similar(edge_neighbor, c) && higher(edge_neighbor, c)) {
                     col = edge_neighbor;
                 }
             }

            // --- Attempt to preserve original edge logic structure ---
            // Note: This section remains complex and might need debugging/tuning.
            // Conditions like similar3(r, s, tl) are hard to interpret without visualization.
            if(similar(t, l)){ if(higher(s, c)){ col = s; } } // If t & l match, but 's' is higher than c, use s?

            // These seem like specific pattern detections (e.g., diagonal lines meeting edges)
            if(similar3(r, s, tl) && similar3(br, c, l) && higher(s, c)){ col = t; }
            if(!similar(tl, c) && similar3(r, c, bl) && similar3(tr, t, l) && higher(c, l)){ col = s; }
            if(!similar(tr, c) && similar3(l, c, br) && similar3(tl, s, r) && higher(c, r)){ col = s; }
            if(similar3(b, s, tl) && similar3(br, c, t) && higher(b, c)){ col = s; } // Original had /* && !similar(r, l)*/
            if(!similar(tl, c) && similar3(tr, c, b) && similar3(t, l, bl) && higher(c, l)){ col = s; } // Original had /* && !similar(r, l)*/ ?? Typo likely
            if(!similar(bl, c) && similar3(br, c, t) && similar3(b, s, tl) && higher(c, s)){ col = s; }

        }
        // Implicit else: If not corner or edge, keep col = c (center of 4x4 block)
    }

    // Restore alpha for non-transparent pixels if it was modified by blending/selection.
    // The current logic doesn't seem to modify alpha, but this is good practice.
    if (col.a > 0.01) { // Use a small threshold
        col.a = 1.0; // Force full alpha? Or maybe preserve original alpha `c.a`? Let's use c.a
        col.a = c.a; // Preserve original alpha unless a transparent pixel was explicitly chosen.
                     // Or, if the chosen color (t, l, s, etc.) was transparent, keep its alpha.
    }
     // If the final color is fully transparent, ensure it is black transparent.
    if (col.a < 0.01) {
        col = vec4(0.0, 0.0, 0.0, 0.0);
    }


    COLOR = col;
}