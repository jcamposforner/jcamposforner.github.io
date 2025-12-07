---
title: "Navigation Systems: Why Body Frames Matter"
description: "A point in space only has meaning when expressed in a reference frame. Learn why body frames like RFU or FRD are essential for describing positions, orientations, and observations from multiple observers."
categories: [ Navigation, Body Frame, Coordinate Frames ]
tags: [ Navigation, Coordinate Systems, Reference Frames, Body Frame, NED, Orientation, Position, Geospatial ]
hidden: false
math: true
read_complexity: 2
---


Before reading this post, make sure you’re familiar with the previous chapters in this series, as they establish the
foundations for frames of reference in navigation systems.

1. [**Why Coordinate Frames Matter**](/posts/coordinates-frames/){:target="_blank"}

## Introduction

[Remember our coordinate frame confusion?](/posts/coordinates-frames/){:target="_blank"} It gets even more interesting
when two observers are looking at the same
object. This is where body frames become absolutely essential.

The fundamental remains: **everything is relative**.

## The Pointing Problem

When we point at an object, we're essentially creating two angles: **azimuth** and **elevation**. In navigation, this
combination is called **Bearing**.

- **Azimuth**: How far left or right you're pointing from your forward direction
- **Elevation**: How far up or down you're pointing from your horizontal plane

![guy-pointing](/assets/img/navigation/body-frames/guy-pointing.png)
---

This is exactly what sensors do. They **point** at targets and send these two angles plus the distance. This is a
[**spherical coordinates**](https://en.wikipedia.org/wiki/Spherical_coordinate_system){:target="_blank"}

Your measurements only make sense relative to your orientation. Your friend with a different orientation
will measure completely for the same target.

This becomes critical when multiple observers need to share information about the same targets.

## What Is Body Frame?

A body frame solves this problem by creating a coordinate system that moves with the object.

You already use body frames intuitively. When you say **turn left at the intersection**, you're using the car's body
frame. Left and right are defined relative to the car orientation.

Body frames formalize this intuitive concept mathematically. Once we attach coordinate axes to an object, we can
describe anything else relative to that object using standard operations.

When you **turn left**, the body frame **turns left with you**. This ensures directions like **forward** and **right**
always have consistent meaning relative to the object.

### Forward-Right-Down (FRD)

**FRD** is the standard in aviation. The forward axis points where the aircraft is going, the right axis points toward
the wing, and the down axis points toward the ground. This convention matches how pilots naturally think about
flight.

![frd](/assets/img/navigation/body-frames/frd.png)
<center><em>FRD</em></center>

---

### Right-Forward-Up (RFU)

**RFU** feels more natural for ground-based applications because up works particularly well for sensor systems
describing
elevated targets.

![rfu](/assets/img/navigation/body-frames/rfu.png)
<center><em>RFU</em></center>

--- 
**_Both conventions are mathematically equivalent. You can convert between them with simple axis rotations,
but one may feel more intuitive for specific applications._**

## Describing Body Frame Orientation: Euler angles

To describe orientation in a 3D plane we need to use three rotations. Navigation systems
typically use the Tait-Bryan convention, better known as roll-pitch-yaw.

![yaw-pitch-roll](/assets/img/navigation/body-frames/yaw-pitch-roll.png)
<center><em>Tait-Bryan angles</em></center>

- **Yaw (ψ)**: Rotation around the vertical axis. **Which way are you facing?** This is like turning your head left or
  right
  while standing upright
- **Pitch (θ)**: Rotation around the lateral axis. **Are you looking up or down?** This is like nodding your
  head up and down
- **Roll (φ)**: Rotation around the longitudinal axis. **Are you tilted left or right?** This is like
  tilting your head to touch your ear to your shoulder

One limitation is that Euler angles can suffer from [gimbal lock](https://en.wikipedia.org/wiki/Gimbal_lock){:target="_
blank"}, a situation where two axes align and orientation becomes
ambiguous.

![gimbal lock](/assets/img/navigation/body-frames/gimbal-lock.gif)
<center><em>Gimbal lock</em></center>
---

To avoid these issues, we often convert roll-pitch-yaw into a [quaternion](https://en.wikipedia.org/wiki/Quaternion){:
target="_blank"}.

![quaternion code](/assets/img/navigation/body-frames/rotation_quat.png)

## What is an Spherical Coordinate

[**Spherical coordinates**](https://en.wikipedia.org/wiki/Spherical_coordinate_system){:target="_blank"} describe where
a point is located relative to an observer.

A point in 3D space is expressed with three values:

- **r**: Distance from the observer to the target
- **Theta (θ)**: Elevation angle
- **Phi (ϕ)**: Azimuth angle

**_Theta and Phi differ in conventions, the ones shown in the earlier functions follow the physics convention_**

This is exactly how sensors like radars, LiDARs, and cameras describe what they **see**

![spherical coordinate example](/assets/img/navigation/body-frames/spherical-coordinate.png)
<center><em>Spherical Coordinate Analogy</em></center>
---

### Spherical to Cartesian

To convert a point from **spherical coordinates** to **Cartesian coordinates** in
the body frame, we use the following formula:

$$
\begin{aligned}
x &= r \cdot \sin\theta \cdot \cos\phi \\
y &= r \cdot \sin\theta \cdot \sin\phi \\
z &= r \cdot \cos\theta
\end{aligned}
$$

Because **θ** in spherical coordinates is measured from the vertical axis (z-axis), we need to align the elevation
with the body frame’s z-axis orientation.

#### FRD Adjustments

$$
\theta_\text{FRD} = \text{elevation}_\text + 90^\circ
$$

#### RFU Adjustments

$$
\begin{aligned}
\theta_\text{RFU} = 90^\circ - \text{elevation} \\
\phi_\text{RFU} = 90^\circ - \text{azimuth}
\end{aligned}
$$


<center>
In <b>RFU</b>, also forward/right axes are swapped, so we need to modify the azimuth.
</center>

---

![spherical to cartesian](/assets/img/navigation/body-frames/frd_spherical_transformations.png)
<center><em>Spherical to Cartesian</em></center>

## Resolving the Pointing Problem

Let's walk through a concrete example using **FRD** that shows exactly why body frames are essential for navigation.

- **Observer 1**: Our reference observer
- **Observer 2**: Positioned 4 meters forward from **Observer 1**, with the following orientation (yaw = 45°, pitch =
  0°, roll =
  0°)

**Observer 2** spots a target at:

- Azimuth: 45°
- Distance: 10 meters
- Elevation: 0°

So, where is this target relative to **Observer 1**? What coordinates would **Observer 1** use to describe the same
target?

![attitude](/assets/img/navigation/body-frames/frd_planes.png)
<center><em>Observation</em></center>

---

First, we define the orientation of **Observer 2** FRD frame relative to **Observer 1** FRD frame. This allows us to
know
how **Observer 2** is oriented and the translation where **Observer 2** is located when moving points from one frame to
the
other.

Once we have this transformation set up, we take the bearing and distance from **Observer 2** sensor data and convert
them
from spherical coordinates to Cartesian coordinates in **Observer 2** body frame.

Finally, using the previously defined rotation and translation, we transform the target coordinates from **Observer 2**
frame to **Observer 1** frame. This gives **Observer 1** the same target location in their own coordinate system.

For the reverse operation, from Observer 1’s FRD frame to Observer 2’s FRD frame, we need to **invert the transformation
**:

$$
\mathbf{T}_{\text{FRD2←FRD1}} = \mathbf{T}_{\text{FRD1←FRD2}}^{-1}
$$

**where $$\mathbf{T}_{\text{FRD1←FRD2}}$$ is the original rotation + translation from FRD2 to FRD1.**

![spherical to cartesian](/assets/img/navigation/body-frames/frd2_to_frd1.png)
<center><em>Multiple observers code solution</em></center>

## Applications where body frames are essential

Body frames are not just theory, they show up in almost every modern navigation system:

- **Aviation and UAVs**: Flight dynamics, autopilot control, and sensor data are all expressed in the aircraft body
  frame (usually **FRD**).
- **Ground vehicles and robotics**: LiDAR scans, and SLAM maps uses RFU before converting to **WGS84**.
- **Maritime systems**: Ships use body frames to define headings, sensor mounts, and relative target bearings.
- **Defense and tracking systems**: Radars and sensors always report detections relative to their own pointing
  direction.
- **Sensor fusion (GNSS/INS)**: INS returns velocity and acceleration in **RFU** or **FRD**, which must be converted to
  a global frame like **WGS84**.

Whenever multiple observers or sensors need to share information, the body frame is the first step.

## So What's Next?

By now you have seen why **left, right, up, down** are not universal, they only make sense once tied to a body frame.

But navigation doesn't stop there. To interact with the real world, we also need to understand how the Earth itself is
represented.

**Next up: We'll explore [geodetic coordinates and how the Earth is
modeled](/posts/earth-coordinates/#converting-between-coordinate-systems){:target="_blank"}** the foundation for
connecting local
movement to the planet.