---
title: "Building a Geospatial Index from Scratch: First Steps"
description: "Learn the fundamentals of geospatial indexes and how to start building one from scratch"
date: 2025-01-02 18:00:00 +0000
last_modified_at: 2025-01-02 18:00:00 +0000
categories: [ Geospatial, Hextree ]
tags: [ Geospatial, Hextree, Algorithms, Data Structure ]
math: true
---

In this post, we’ll explore the foundational steps to build a geospatial index based on a hexagonal grid. While we won't
deep into
code, I'll show the core ideas and steps to get you started.

---

## Understanding Hexagonal Geospatial Indexes

Hexagonal grids are often preferred for geospatial indexing because they provide better uniformity and less distortion
compared to square grids. Each hexagon has:

1. **Equal Distance:** Uniform distance to neighboring hexagons.
2. **Compactness:** Close to a circle in shape, making them efficient for covering areas.
3. **Hierarchy:** Ability to create finer resolutions by subdividing parent hexagons into smaller ones.

---

## First Steps: Generating the Initial Hexagons

### 1. **Finding the Initial Hexagons**

The process begins by selecting a central point and generating a set of hexagons around it. Here’s how:

- **Start with a Centroid:** Choose a centroid from your set of coordinates.
- **Generate Centers:** Calculate the centers of the surrounding hexagons based on the centroid.
- **Store the Centers:** Save the coordinates of these hexagon centers, this will allow you to recreate the
  initial grid when needed.

### 2. **Building the Hexagonal Hierarchy**

For the next resolution:

- **Subdivide the Hexagon:** Each hexagon at the current level is divided into 7 smaller hexagons.
- **Spacing:** To ensure the smaller hexagons fit perfectly within their parent, their spacing is derived using the \\(
  \\sqrt{7}\\)
- **Rotation:** The smaller hexagons are rotated by approximately \\(19^\\circ\\) for precise alignment.

### 3. **Generating a Hexagon**

To generate a hexagon given its center and radius:

- Let \\((c_x, c_y)\\) be the coordinates of the hexagon's center.
- Let \\(r\\) be the radius of the hexagon.
- The six vertices \\((v_x, v_y)\\) can be calculated as:

\\[
v_x = c_x + r \\cdot \\cos(\\theta)
\\]
\\[
v_y = c_y + r \\cdot \\sin(\\theta)
\\]

Where:

\\[
\\theta = \\frac{\\pi}{3} \\cdot i \\quad \\text{for } i \\in \\{0, 1, 2, 3, 4, 5\\}
\\]

- These vertices form the outline of the hexagon and can be used to plot it or perform calculations.

### 4. **Generating Neighbors**

Navigating a hexagonal grid is straightforward thanks to its uniformity, each hexagon has 6 neighbors, and visiting
them can be achieved by calculating their centers.

To calculate the coordinates of the 6 neighbors given a center at \\((c_x, c_y)\\), radius \\(r\\), the following formulas are used:

1. **Upper-left Neighbor:**
   \\[
   (c_{x1}, c_{y1}) = (c_x - r \\cdot \\cos(30^\\circ), c_y + r \\cdot \\sin(30^\\circ))
   \\]

2. **Upper-right Neighbor:**
   \\[
   (c_{x2}, c_{y2}) = (c_x + r \\cdot \\cos(30^\\circ), c_y + r \\cdot \\sin(30^\\circ))
   \\]

3. **Right Neighbor:**
   \\[
   (c_{x3}, c_{y3}) = (c_x + 2r, c_y)
   \\]

4. **Lower-right Neighbor:**
   \\[
   (c_{x4}, c_{y4}) = (c_x + r \\cdot \\cos(30^\\circ), c_y - r \\cdot \\sin(30^\\circ))
   \\]

5. **Lower-left Neighbor:**
   \\[
   (c_{x5}, c_{y5}) = (c_x - r \\cdot \\cos(30^\\circ), c_y - r \\cdot \\sin(30^\\circ))
   \\]

6. **Left Neighbor:**
   \\[
   (c_{x6}, c_{y6}) = (c_x - 2r, c_y)
   \\]

These formulas allow for the calculation of the exact positions of the neighboring hexagons from a central hexagon.

### 5. **Winding Number Algorithm for Point-in-Hexagon Check**

To determine if a point \\((p_x, p_y)\\) lies inside a hexagon, you can use the **winding number algorithm**. This
involves calculating the angle subtended by each edge of the hexagon at the point:


1. Initialize the \\( winding\\_number = 0 \\).

2. For each edge of the polygon, consider two consecutive vertices \\( p_1 = (x_1, y_1) \\) and \\( p_2 = (x_2, y_2) \\). For each edge, check the following condition:

   If \\( y_1 \\leq y_{\\text{coord}} \\) and \\( y_2 > y_{\\text{coord}} \\), check if the point lies to the left of the edge. This is done by calculating the cross product:

   \\[
   \\text{cross\_product} = (x_2 - x_1) \\cdot (y_{\\text{coord}} - y_1) - (x_{\\text{coord}} - x_1) \\cdot (y_2 - y_1)
   \\]

   If the result of the cross product is positive, increment \\( winding\\_number \\):

   \\[
   winding\\_number = winding\\_number + 1
   \\]

   If \\( y_2 \\leq y_{\\text{coord}} \\) and \\( y_1 > y_{\\text{coord}} \\), check if the point is to the right of the edge:

   \\[
   \\text{cross\_product} = (x_2 - x_1) \\cdot (y_{\\text{coord}} - y_1) - (x_{\\text{coord}} - x_1) \\cdot (y_2 - y_1)
   \\]

   If the result is negative, decrement \\( winding\\_number \\):

   \\[
   winding\\_number = winding\\_number - 1
   \\]

5. **Check the result**:

- If the **winding_number** is non-zero, the point is **inside** the hexagon.
- If the **winding_number** is zero, the point is **outside** the hexagon.

_This method works for any polygon, not just hexagons._

---

## Unique Hexagon IDs

Each hexagon is assigned a unique identifier using a binary encoding system:

1. **Binary Composition:** Each ID is constructed from multiple binary digits.
2. **Bit Shifts:** The binary digits are assigned to specific parts of the ID using bit shifts:

- The first `u8` uses 7 bits.
- The second `u8` uses 3 bits.
- The third `u8` uses 3 bits.
- A total of 4 bits complete the ID.

3. **Example ID:** For instance, an ID might look like `10100110011` in binary.

---

## Identifying Hexagons

### 1. **Locating Initial Hexagons**

To identify the first set of hexagons, a **KD-Tree** is employed. This structure efficiently finds the closest points to
the centroid, which represent the centers of the initial hexagons. To determine if a point is within a given hexagon,
the **Haversine formula** can be used:

- Given two points `(lat1, lon1)` and `(lat2, lon2)`:

\\[
a = \\sin^2\\left(\\frac{\\text{lat}_2 - \\text{lat}_1}{2}\\right) + \\cos(\\text{lat}_1) \\cdot \\cos(\\text{lat}_2) \\cdot \\sin^2\\left(\\frac{\\text{lon}_2 - \\text{lon}_1}{2}\\right)
\\]

\\[
c = 2 \\cdot \\text{atan2}\\left(\\sqrt{a}, \\sqrt{1-a}\\right)
\\]

\\[
\\text{distance} = R \\cdot c
\\]

Where:

- \\(\\text{lat}_1, \\text{lat}_2\\): Latitudes of the two points in radians.
- \\(\\text{lon}_1, \\text{lon}_2\\): Longitudes of the two points in radians.
- \\(R\\): Radius (mean radius = 6,371 km).

If the distance is less than the hexagon's radius, the point is
inside.

### 2. **Locating Sub-Hexagons**

Once the parent hexagons are defined, the centers of their 7 sub-hexagons are determined using a brute force approach.
This involves calculating the positions relative to the parent and validating their placement.

---

## Things to Consider

When working with geospatial data and hexagonal grids, it’s important to keep the following factors in mind:

1. **Earth’s Distortion:** The Earth is not a perfect sphere, which introduces distortion when projecting coordinates
   onto a flat plane. Using a suitable map projection can mitigate this distortion for your region of interest.
2. **Projection System:** Choose an appropriate projection system (e.g., Web Mercator, WGS84) to balance accuracy and
   computational efficiency.
3. **Hexagon Size:** The size of the hexagons should be carefully chosen to match the scale and resolution of your
   application.

---

### Final Thoughts

Building a geospatial index from scratch is a challenging but rewarding endeavor. By leveraging hexagonal grids, you
gain access to a powerful tool for spatial indexing with applications in real-time location tracking, geographic
analysis, and more.

## Coming Up Next

Stay tuned for the next post in this series: [**Data Structures and Geometry: The Foundation of a Geospatial Index**](/posts/data-structures-geometry-geospatial-index/).

## Read More

Check out the previous posts about [**Geospatial Indexes**](/categories/geospatial/).
