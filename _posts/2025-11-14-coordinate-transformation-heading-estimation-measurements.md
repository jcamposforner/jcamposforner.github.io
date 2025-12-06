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
isolated in his own frame, and we cannot make any of this.

Think of it this way:

- A radar sees a target at a certain angle and range in its own frame.
- A camera on the same platform sees the same target, but in pixels relative to its optical center.
- An IMU measures accelerations in a completely different orientation.

Without transforming all of these measurements into a common frame, like ENU or NED, we could never determine
where the target really is, how it is moving, or predict its future position.

## Sensors Measure in Their Own Frame

Every sensor reports measurements in its own body frame. For example, a radar report the observations in
spherical coordinates where the axes are defined by the sensor's orientation. This means that even if multiple
sensors observe the same object, each measurement is different until transformed to a common frame.

![radar](/assets/img/navigation/coordinates-transformations/radar.gif){: width="300" }

### Body-Frame Measurements

- IMUs provide acceleration and angular velocity
- Cameras detect pixels relative to their optical center
- Radars measure range and bearing from their antenna

### Radar Spherical Coordinates

The figure shows a radar observing a plane in the distance. The radar reports bearing and distance measurements in its
own body frame.

In this example, the radar’s orientation is aligned with ENU, so the measurements can be directly interpreted in ENU
coordinates.

![enu-observation](/assets/img/navigation/coordinates-transformations/enu-observation.gif)

{: .text-center}
_This was explained more in depth
in the [**Why Body Frames Matter**](/posts/body-frames/#what-is-an-spherical-coordinate){:target="_blank"} post._

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

$$
\text{When}: \\[6pt]
\begin{aligned}
p_1, p_2 \in \text{ENU}
\end{aligned}
$$

We can compute:

$$velocity = \frac{p_2 - p_1}{\Delta t}$$

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
- Velocity estimation
- Heading estimation

![enu-observation](/assets/img/navigation/coordinates-transformations/enu-observation.gif)

### Coordinate Transformation Pipeline

Visualize a pipeline of coordinate transformations.

Radar Spherical -> Radar Cartesian RFU -> ENU -> ECEF -> WGS84

### Code Example

```rust
// We define our systems
cartesian_system!(pub struct RadarEnu using ENU);

fn main() {
    // We know the radar global position
    let radar_wgs84 = Coordinate::<Wgs84>::new(
        Latitude::new(Angle::new::<degree>(33.6954)).unwrap(),
        Longitude::new(Angle::new::<degree>(-78.8802)).unwrap(),
        Altitude::new(Length::new::<meter>(3.)),
    );

    // First observation
    let radar_aircraft_observation = Observation::new(
        Coordinate::<RadarEnu>::from_bearing(
            Bearing::new(Azimuth::from_degrees(129.3), Elevation::from_degrees(23.7)),
            Length::new::<meter>(173.5),
        ),
        SystemTime::now(),
    );

    // Second observation after 2 seconds
    let radar_aircraft_second_observation = Observation::new(
        Coordinate::<RadarEnu>::from_bearing(
            Bearing::new(Azimuth::from_degrees(102.0), Elevation::from_degrees(28.0)),
            Length::new::<meter>(171.6),
        ),
        SystemTime::now() + Duration::from_secs(2),
    );

    let transform_ecef_to_ground_enu = RigidBodyTransform::wgs84_to_enu(&radar_wgs84);
    let first_observation_ecef =
        transform_ecef_to_ground_enu.inverse_transform(*radar_aircraft_observation.observation());
    let second_observation_ecef = transform_ecef_to_ground_enu
        .inverse_transform(*radar_aircraft_second_observation.observation());

    println!(
        "Radar confirmed aircraft at {}",
        &first_observation_ecef.to_wgs84()
    );
    println!(
        "Radar confirmed aircraft at {} after 2 seconds",
        &second_observation_ecef.to_wgs84()
    );

    let observation_pair = PairObservation::new(
        radar_aircraft_observation,
        radar_aircraft_second_observation,
    );

    let velocity = observation_pair.velocity();
    let orientation = observation_pair.orientation(Roll::from_degrees(0.0));

    // Radar confirmed aircraft at 33.69449280498643°N, 78.87887402595308°W, 72.73991943263148m
    // Radar confirmed aircraft at 33.69511598353151°N, 78.87860151788037°W, 83.56311827725594m after 2 seconds
    // Estimated Velocity 37.19303456899246 m/s (12.632376154427835, 34.56094180765216, 5.411672062439869)
    // Roll: 0.000000 deg, Pitch: 8.366367 deg, Yaw: 69.922127 deg measured from East towards North
}
```

## Second Problem: Distributed Tracking

### Scenario Description

After the first problem present the next problem about the same moving target reporting to the ENU base station, and
observation of a moving car. So we need to take the estimated heading from the first object and get the same DT
observation to calculate the second object position / heading ( Course Over Ground ) because we don't know where the
first object is pointing the only we know is the direction.

![enu-multiple-observation](/assets/img/navigation/coordinates-transformations/enu-multiple-observation.gif)

### Line of Sight (LOS)

Line of Sight (LOS)

The vector to get from the observer coordinate to the target coordinate.

FORMULA

```rust
```

### Resolution

```rust
```

## Third Problem: Local Attitude to Point Toward a Known Target

### Scenario Description

Now we have the target's absolute position expressed in WGS-84 (lat, lon, alt).
We also know the observer’s absolute position in WGS-84.

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