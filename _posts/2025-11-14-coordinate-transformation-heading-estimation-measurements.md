---
title: "Navigation Systems: Target Acquisition"
description: "A comprehensive guide to coordinate transformations in navigation systems, from sensor measurements to target tracking and heading estimation"
categories: [ Navigation, Coordinate Transformations, Coordinate Frames, Target Tracking, Sensor Fusion ]
tags: [ Navigation, Coordinate Systems, Reference Frames, Earth Coordinates, Earth, NED, Orientation, Position, Geospatial, Bearing Measurements, Heading Estimation ]
hidden: false
math: true
read_complexity: 2.0
---

Before reading this post, make sure you’re familiar with the previous chapters in this series, as they establish the
foundations for frames, navigation, and orientation:

1. [**Why Coordinate Frames Matter**](/posts/coordinates-frames/){:target="_blank"}
2. [**Why Body Frames Matter**](/posts/body-frames/){:target="_blank"}
3. [**Earth Coordinates**](/posts/earth-coordinates/){:target="_blank"}
4. [**Local Tangent Plane**](/posts/local-tangent-plane/){:target="_blank"}

## Introduction

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
isolated in his [**own frame**](/posts/body-frames/){:target="_blank"}, and we cannot make any of this.

Think of it this way:

- A radar sees a target at a certain angle and range in its [**own frame**](/posts/body-frames/){:target="_blank"}.
- A camera on the same platform sees the same target, but in pixels relative to its optical center.
- An IMU measures accelerations in a completely different orientation.

Without transforming all of these measurements into a common frame,
like [**ENU or NED**](/posts/local-tangent-plane/){:target="_blank"}, we could never determine where the target really
is, how it is moving, or predict its future position.

## Sensors Measure in Their Own Frame

Every sensor reports measurements in its own body frame. For example, a radar report the observations in
spherical coordinates where the axes are defined by the sensor's orientation. This means that even if multiple
sensors observe the same object, each measurement is different until transformed to a common frame.

![radar](/assets/img/navigation/coordinates-transformations/radar.gif){: width="300" }
<center><em>Figure 1: Radar</em></center>

### Body-Frame Measurements

- IMUs provide acceleration and angular velocity
- Cameras detect pixels relative to their optical center
- Radars measure range and bearing from their antenna

### Radar Spherical Coordinates

The figure shows a radar observing a plane in the distance. The radar reports bearing and distance measurements in its
own body frame.

In this example, the radar’s orientation is aligned with
[**ENU**](/posts/local-tangent-plane/#east-north-up-enu){:target="_blank"}, so the measurements can be directly
interpreted in
[**ENU**](/posts/local-tangent-plane/#east-north-up-enu){:target="_blank"}
coordinates.

![enu-observation](/assets/img/navigation/coordinates-transformations/enu-observation.gif)
<center><em>Figure 2: ENU Observation</em></center>

---

{: .text-center}
_This was explained more in depth
in the [**Why Body Frames Matter**](/posts/body-frames/#what-is-an-spherical-coordinate){:target="_blank"} post._

## Why Origins Matters

It's not enough to know the direction of the measurement, you must also know where sensor is located
in a global reference fame, two identical bearing measurements have completely different meanings if:

- The sensor is at the origin of the [**ENU**](/posts/local-tangent-plane/#east-north-up-enu){:target="_blank"} frame
- The sensor is located at 2km east (2000,0,0)
- The [**WGS84**](/posts/earth-coordinates/){:target="_blank"} origin is different

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

{: .text-center}
**Given a vector** $$\vec{v} = (x, y, z) \neq (0,0,0) \\[8pt]$$

{: .text-center}
**1. ENU (East-North-Up, +Z = up, pitch positive = nose up):**

$$
\begin{aligned}
\text{Yaw:} \quad & \psi = \operatorname{atan2}(y, x) \\[2mm]
\text{Pitch:} \quad & \theta = \operatorname{atan2}\big(z, \sqrt{x^2 + y^2}\big)
\end{aligned}
$$

{: .text-center}
**2. NED (North-East-Down, +Z = down, pitch positive = nose up):**

$$
\begin{aligned}
\text{Yaw:} \quad & \psi = \operatorname{atan2}(y, x) \\[2mm]
\text{Pitch:} \quad & \theta = \operatorname{atan2}\big(-z, \sqrt{x^2 + y^2}\big)
\end{aligned}
$$

---

<center><em><small><b>Notes</b></small></em></center>

<ul>
<li>
  <em><small>In ENU, Z points up, so pitch positive means nose up.</small></em>
</li>
<li>
  <em><small>In NED, Z points down, so we flip the sign (-z) so that pitch positive still means nose up.</small></em>
</li>
</ul>

---

```rust
struct Vector<CoordinateFrame> {
    inner: nalgebra::Vector3,
    _system: PhantomData<CoordinateFrame>,
}

impl<CoordinateFrame> Vector<CoordinateFrame>
where
    CoordinateFrame: CartesianSystem + PitchConvention,
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
        let pitch_convention = CoordinateFrame::pitch_convention();
        let pitch = Angle::new::<radian>((pitch_convention * z).atan2(dist_horizontal));

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
<center><em>Figure 3: Radar Observation</em></center>

### Coordinate Transformation Pipeline

To know how to transform these observations into world coordinates, we need to know the radar's global position in
[**WGS84**](/posts/earth-coordinates/){:target="_blank"} and its orientation ( here **aligned** with **ENU** for
**simplicity** ), but we should transform from body frame to ENU / NED.

![coordinate-transformation-pipeline](/assets/img/navigation/coordinates-transformations/coordinate-transformation-pipeline.png)
<center><em>Figure 4: Coordinate Transformation Pipeline</em></center>

---

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
        DateTime::parse_from_rfc3339("2025-11-14T12:00:00Z")
            .unwrap()
            .with_timezone(&Utc),
    );

    // Second observation after 2 seconds
    let radar_aircraft_second_observation = Observation::new(
        Coordinate::<RadarEnu>::from_bearing(
            Bearing::new(Azimuth::from_degrees(102.0), Elevation::from_degrees(28.0)),
            Length::new::<meter>(171.6),
        ),
        DateTime::parse_from_rfc3339("2025-11-14T12:00:02Z")
            .unwrap()
            .with_timezone(&Utc),
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
    // Roll: 0.000000 deg, Pitch: ∼8.36 deg, Yaw: ∼70 deg measured from East towards North or 20 deg from North towards East
}
```

---

<center><em><small><b>Notes</b></small></em></center>

<ul>
<li>
  <em><small>The time of 2 seconds between observations is arbitrary for demonstration purposes. So it's not realistic</small></em>
</li>
</ul>

---

## Second Problem: Distributed Tracking

### Scenario Description

After the first problem present the next problem about the same moving target reporting to the ENU base station, and
observation of a moving car. So we need to take the estimated heading from the first object and get the same DT
observation to calculate the second object position / heading ( Course Over Ground ) because we don't know where the
first object is pointing the only we know is the direction.

![enu-multiple-observation](/assets/img/navigation/coordinates-transformations/enu-multiple-observation.gif)
<center><em>Figure 5: ENU Distributed Observation</em></center>

### Line of Sight (LOS)

Line of Sight (LOS)

The vector to get from the observer coordinate to the target coordinate.

FORMULA

```rust
```

### Resolution

```rust
cartesian_system!(pub struct RadarENU using ENU);
cartesian_system!(pub struct AircraftNED using NED);
cartesian_system!(pub struct AircraftFRD using FRD);

struct Radar {
    wgs84: Coordinate<Wgs84>,
    transformer: RigidBodyTransform<ECEF, RadarENU>,
}

impl Radar {
    fn new(wgs84: Coordinate<Wgs84>) -> Self {
        let transformer = RigidBodyTransform::wgs84_to_enu(&wgs84);

        Self { wgs84, transformer }
    }

    fn observe(&self, bearing: Bearing<RadarENU>, distance: Length) -> Coordinate<ECEF> {
        let radar_observation = Coordinate::<RadarENU>::from_bearing(bearing, distance);

        self.transformer.inverse_transform(radar_observation)
    }

    fn transform_to_enu(&self, coord: Coordinate<ECEF>) -> Coordinate<RadarENU> {
        self.transformer.transform(coord)
    }
}

struct Aircraft {
    wgs84: Coordinate<Wgs84>,
    pose: Pose<AircraftNED>,
    transformer_ned: RigidBodyTransform<ECEF, AircraftNED>,
    transformer: RigidBodyTransform<ECEF, AircraftFRD>,
}

impl Aircraft {
    fn new(pose: Pose<AircraftNED>, wgs84: Coordinate<Wgs84>) -> Self {
        let ecef_to_aircraft_ned = RigidBodyTransform::wgs84_to_ned(&wgs84);
        let ecef_to_aircraft_frd = ecef_to_aircraft_ned.and_then(pose.as_transform());

        Self {
            wgs84,
            pose,
            transformer: ecef_to_aircraft_frd,
            transformer_ned: ecef_to_aircraft_ned,
        }
    }

    fn observe(&self, bearing: Bearing<AircraftFRD>, distance: Length) -> Coordinate<ECEF> {
        let aircraft_observation = Coordinate::<AircraftFRD>::from_bearing(bearing, distance);

        self.transformer.inverse_transform(aircraft_observation)
    }

    fn change_origin(&mut self, new_origin: Coordinate<ECEF>) {
        self.pose = Pose::new(
            self.transformer_ned.transform(new_origin),
            self.pose.orientation(),
        );

        self.transformer = self.transformer_ned.and_then(self.pose.as_transform());
    }
}

fn main() {
    let radar_wgs84 = Coordinate::<Wgs84>::new(
        Latitude::new(Angle::new::<degree>(33.6954)).unwrap(),
        Longitude::new(Angle::new::<degree>(-78.8802)).unwrap(),
        Altitude::new(Length::new::<meter>(0.)),
    );

    let radar = Radar::new(radar_wgs84);

    let ecef_first_aircraft_observation = radar.observe(
        Bearing::new(Azimuth::from_degrees(120.5), Elevation::from_degrees(25.7)),
        Length::new::<meter>(169.2),
    );

    let ecef_second_aircraft_observation = radar.observe(
        Bearing::new(Azimuth::from_degrees(106.2), Elevation::from_degrees(27.7)),
        Length::new::<meter>(169.8),
    );

    // Pitch: ∼8.36, Yaw: ∼70 (ENU) -> NED => Yaw: 20
    let aircraft_pose = Pose::from_origin(Orientation::from_tait_bryan(TaitBryanAngles::new(
        Roll::from_degrees(0.),
        Pitch::from_degrees(8.530765),
        Yaw::from_degrees(20.),
    )));

    let mut aircraft = Aircraft::new(aircraft_pose, ecef_first_aircraft_observation.to_wgs84());

    let car_position_in_ecef = aircraft.observe(
        Bearing::new(Azimuth::from_degrees(252.9), Elevation::from_degrees(-9.1)),
        Length::new::<meter>(444.4),
    );

    let car_position_in_radar_enu = radar.transform_to_enu(car_position_in_ecef);

    aircraft.change_origin(ecef_second_aircraft_observation);

    let car_second_position_in_ecef = aircraft.observe(
        Bearing::new(Azimuth::from_degrees(247.2), Elevation::from_degrees(-9.9)),
        Length::new::<meter>(442.0),
    );

    let car_second_position = radar.transform_to_enu(car_second_position_in_ecef);

    let enu_observation_pair = PairObservation::new(
        Observation::new(
            car_position_in_radar_enu,
            DateTime::parse_from_rfc3339("2025-11-14T12:00:00Z")
                .unwrap()
                .with_timezone(&Utc),
        ),
        Observation::new(
            car_second_position,
            DateTime::parse_from_rfc3339("2025-11-14T12:00:02Z")
                .unwrap()
                .with_timezone(&Utc),
        ),
    );

    let velocity = enu_observation_pair.velocity();
    let orientation = enu_observation_pair.orientation(Roll::from_degrees(0.0));

    // Car first position from Radar: (-302.8269194262102, -44.04597112070769, -15.26327744498849)
    // Car first distance from Radar: 306.3937961831103m
    // Car second position from Radar: (-286.03603694355115, -50.871090973727405, -21.242668790742755)
    // Car second distance from Radar: 291.3000743298618m
    // Car velocity: 9.542917745902352
    // Car orientation (ENU): Roll: 0.000000 deg, Pitch: -18.257582 deg, Yaw: -22.120647 deg
}
```

---

<center><em><small><b>Notes</b></small></em></center>

<ul>
<li>
  <em><small>The pose and the time between each observations are not realistic, just for demonstration purposes. That's why the car has a pitch of -18º.</small></em>
</li>
<li>
  <em><small>The calculated pitch of -18º is incorrect due to vertical position errors (~15-21m) caused by limited precision in the aircraft's pitch angle and approximate timing, which compound when deriving orientation from position changes.</small></em>
</li>
<li>
  <em><small>The calculated yaw of -22º is correct, because the car is moving to south-east relative to the radar position.</small></em>
</li>
<li>
  <em><small>The Radar is UP by 10 meters, so the observations has to consider that altitude.</small></em>
</li>
</ul>

---

## Third Problem: Local Attitude to Point Toward a Known Target

### Scenario Description

Now we have the target's absolute position expressed in WGS-84 (lat, lon, alt).
We also know the observer’s absolute position in WGS-84.

## Landmark Navigation

Landmark navigation, convergence algorithm to estimate position based on multiple observations from known landmarks.

### Observing a Known Landmark

Example of a known landmark

![landmark](/assets/img/navigation/coordinates-transformations/sagrada-familia.png)
<center><em><small>Figure 6: La Sagrada Familia, Barcelona, Spain </small></em></center>

### Convergence algorithm

Explain convergence algorithm to estimate observer position based on landmark observation. And why it needs to be
iterative
---

```rust
pub struct LandmarkObservation<System> {
    pub(crate) position: Coordinate<System>,
    _system: std::marker::PhantomData<System>,
}

const CONVERGENCE_THRESHOLD: f64 = 1e-6;
// It should converge in max 3 iterations
const CONVERGENCE_MAX_ITERATIONS: Range<u8> = 0..3;

impl<System> LandmarkObservation<System>
where
    System: CartesianSystem + Copy,
    System::CoordinateKind: LocalFrameTransform<System>,
{
    pub fn estimate_observer_global_position(
        &self,
        landmark: &Landmark<Wgs84>,
    ) -> Coordinate<Wgs84> {
        let landmark_ecef = landmark.position.to_ecef();

        // Initial estimate of observer position is the landmark position, which will be refined
        let mut observer_position_estimate = landmark.position;
        let observer_to_landmark_ltp = self.position;

        for _ in CONVERGENCE_MAX_ITERATIONS {
            let wgs84_to_ltp = System::CoordinateKind::from_wgs84_origin(&observer_position_estimate);
            let ltp_to_ecef = wgs84_to_ltp.inverse();

            let observer_to_landmark_point = observer_to_landmark_ltp;
            let landmark_calculated_ecef = ltp_to_ecef.transform(observer_to_landmark_point);

            // Calculate the error vector between the calculated landmark position and the known landmark position
            let error_vector = landmark_calculated_ecef.to_point() - landmark_ecef.to_point();

            let observer_ecef_current = observer_position_estimate.to_ecef();

            // Apply the correction to the observer's ECEF position estimation
            let observer_ecef_corrected = Coordinate::<ECEF>::from_point(observer_ecef_current.to_point() - error_vector);

            observer_position_estimate = observer_ecef_corrected.to_wgs84();

            let error_magnitude = error_vector.norm();
            if error_magnitude <= CONVERGENCE_THRESHOLD {
                return observer_position_estimate;
            }
        }

        observer_position_estimate
    }
}
```

--- 
![estimated-distance-landmark](/assets/img/navigation/coordinates-transformations/estimated-distance.png){: width="
640" }
<center><em><small>Figure 7: Estimated position </small></em></center>

## What we can do with this estimations

Explain what we can do with these estimations, like sensor fusion, tracking, know the distances from multiple targets,
calculate spherical coordinates to lock on targets, how to know if we're approaching or moving away from them, how to
know if it is the same target.

## So What’s Next?

Explain that these estimations are useful for sensor fusion and tracking, but they can have errors due to noise and
other
factors. Introduce the idea of Kalman Filters.