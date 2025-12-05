---
title: "Navigation Systems: Target Acquisition"
description: "A comprehensive guide to coordinate transformations in navigation systems, from sensor measurements to target tracking and heading estimation"
categories: [ Navigation, Coordinate Transformations, Coordinate Frames, Target Tracking, Sensor Fusion ]
tags: [ Navigation, Coordinate Systems, Reference Frames, Earth Coordinates, Earth, NED, Orientation, Position, Geospatial, Bearing Measurements, Heading Estimation ]
hidden: false
math: true
read_complexity: 2.0
---

Sensors never measure the world in a global reference frame, they measure what
they see relative to themselfs. But navigation, tracking and sensor fusion requires
that all observations are on the same frame.

Without transforming the sensors observations into the same frame, we could not:

- Combine measurements from multiple sensors
- Track a target's position over time
- Estimate motion
- Multi-sensor fusion would be impossible

These coordinates transformations is the gap between what each sensors see and what we need
to know to navigate, track and making decisions. Without them, each sensor observation is
isolated in his own frame and we cannot make any of this.

Think of it this way:

- A radar sees a target at a certain angle and range in its own frame.
- A camera on the same platform sees the same target, but in pixels relative to its optical center.
- An IMU measures accelerations in a completely different orientation.

Without transforming all of these measurements into a common frame, like ENU or NED, we could never determine
where the target really is, how it is moving, or predict its future position.

## Sensors Measure in Their Own Frame

Every sensor reports measurements in its own body frame.

IMAGE OF BODY FRAME FROM OLDER POST

### Body-Frame Measurements

- IMUs provide acceleration and angular velocity
- Cameras detect pixels relative to their optical center
- Radars measure range and bearing from their antenna

### Radar Shperical Coordinates

![radar](/assets/img/navigation/coordinates-transformations/radar.gif)

The figure shows a radar observing a plane in the distance. The radar reports bearing and distance measurements in its
own body frame.
In this example, the radar’s orientation is aligned with ENU, so the measurements can be directly interpreted in ENU
coordinates.

LINK SPHERICAL COORDINATES

![enu-observation](/assets/img/navigation/coordinates-transformations/enu-observation.gif)

## Why Origins Matters

It's not enough to know the direction of the measurement, you must also know where sensor is located
in a global reference fame, two identical bearing measurements have completely different meanings if:

- The sensor is at the origin of the ENU frame
- The sensor is located at 2km east (2000,0,0)
- The WGS84 origin is different

Coordinate systems differ not only by orientation but also by origin.

## Estimating Heading and Velocity of a Moving Object

A radar station observes an unknown target at two different times:

- At time $$t_1$$: Bearing $$\theta_1$$, Azimuth $$\phi_1$$, range $$r_1$$
- At time $$t_2$$: Bearing $$\theta_2$$, Azimuth $$\phi_2$$, range $$r_2$$
- Time difference: $$\Delta t = t_2 - t_1$$

CODE

```rust
```

If both points

$$p_1, p_2 \in \text{ENU} $$

We can compute:

- Velocity

$$v = \frac{p_2 - p_1}{\Delta t}$$

```rust
struct Velocity<CoordinateFrame> {
    inner: nalgebra::Vector3,
    _system: PhantomData<CoordinateFrame>,
}

impl<CoordinateFrame> Velocity<CoordinateFrame>
where
    CoordinateFrame: CartesianSystem,
{
    pub fn between_positions(
        current_coordinate: Coordinate<CoordinateFrame>,
        previous_coordinate: Coordinate<CoordinateFrame>,
        dt: Time,
    ) -> Self {
        let delta_point = current_coordinate.to_point() - previous_coordinate.to_point();
        let velocity = delta_point / dt.get::<second>();
    
        Self {
            inner: velocity,
            system: std::marker::PhantomData,
        }
    }
}
```

- Heading, we cannot get the roll so it need to be passed

$$
\begin{aligned}
&\text{If } (x, y, z) = (0,0,0) \quad \Rightarrow \quad \text{unable to get orientation}. \\[8pt]
\end{aligned}
$$

---

$$
\begin{aligned}
&\text{If } (x, y, z) \neq (0,0,0): \\[6pt]
\psi &= \operatorname{atan2}(y,\, x) \\[4pt]
\theta &= \operatorname{atan2}\!\left(-z,\; \sqrt{x^{2}+y^{2}}\right) \\[4pt]
\end{aligned}
$$

```rust
struct Vector<CoordinateFrame> {
    inner: nalgebra::Vector3,
    _system: PhantomData<CoordinateFrame>,
}

impl<CoordinateFrame> Vector<CoordinateFrame>
where
    CoordinateFrame: CartesianSystem,
{
    pub fn orientation(
        &self,
        roll: Roll,
    ) -> Option<Orientation<CoordinateFrame>> {
        let x = self.inner.x;
        let y = self.inner.y;
        let z = self.inner.z;
        
        if x == 0. && y == 0. && z == 0. {
            return None;
        }

        let yaw = Angle::new::<radian>(y.atan2(x));
        let dist_horizontal = (x.powi(2) + y.powi(2)).sqrt();
        let pitch = Angle::new::<radian>((-z).atan2(dist_horizontal));

        Some(
            Orientation::from_tait_bryan(
                TaitBryanAngles::new(
                    roll,
                    Pitch::new(pitch),
                    Yaw::new(yaw),
                ),
            )
        )
    }
}
```

## First Problem: Estimating Target Position from Radar Measurements

### Scenario Description

A radar observes a target, each observation is a spherical measurement on the radar's body frame. The radar's body frame
for
simplicity will be aligned with ENU.

We want to convert these observations into:

- Position in ENU and world coordinate
- Velocity estimatino
- Heading estimation

![enu-observation](/assets/img/navigation/coordinates-transformations/enu-observation.gif)

### Coordinate Transformation Pipeline

Visualize a pipeline of coordinate transformations.

Radar Spherical -> Radar Cartesian -> ENU

### Where should I look from my Position

Now that I know the plane position I want to know how much should I rotate to point towards it, so we need to convert
from cartesian coordiantes to spherical coordinates.

SPHERICAL COORDIANTE CALCULATED (1º, 12º, 203m)

FORMULA

CODE

```rust
```

### Code Example

```rust
```

## Second Problem: Distributed Tracking

### Scenario Description

After the first problem present the next problem about the same moving target reporting to the ENU base station, and
observation of a moving car. So we need to take the estimated heading from the first object and get the same DT
observation to calculate the second object position / heading ( Course Over Ground ) because we don't know where the
first object is pointing the only we know is the direction.

![enu-multiple-observation](/assets/img/navigation/coordinates-transformations/enu-multiple-observation-2.gif)

### Line of Sight (LOS)

Line of Sight (LOS)

The vector to get from the observer coordinate to the target coordinate.

FORMULA

```rust
```

### Where should I look from my Position

### Resolution

```rust
```

## Landmark Navigation

Landmark navigation, convergence algorithm to estimate position based on multiple observations from known landmarks.

### Observing a Known Landmark

Example of a known landmark

### Convergence algorithm

```rust
```

![landmark](/assets/img/navigation/coordinates-transformations/sagrada-familia.png)

![estimated-distance-landmark](/assets/img/navigation/coordinates-transformations/estimated-distance.png)

```rust
```

## What we can do with this estimations

Explain what we can do with these estimations, like sensor fusion, tracking, know the distances from multiple targets,
calculate spherical coordinates to lock on targets, how to know if we're approaching or moving away from them, how to
know if it is the same target.

## So What’s Next?

Explain that these estimations are useful for sensor fusion and tracking, but they can have errors due to noise and
other
factors. Introduce the idea of Kalman Filters.