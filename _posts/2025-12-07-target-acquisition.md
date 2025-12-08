---
title: "Navigation Systems: Target Acquisition"
description: "A comprehensive guide to coordinate transformations in navigation systems, from sensor measurements to target tracking and orientation estimation"
categories: [ Navigation, Coordinate Transformations, Coordinate Frames, Target Tracking, Sensor Fusion ]
tags: [ Navigation, Coordinate Systems, Reference Frames, Earth Coordinates, Earth, NED, Orientation, Position, Geospatial, Bearing Measurements, Orientation Estimation ]
hidden: false
math: true
read_complexity: 2.0
---

## Prerequisites & Assumptions

Before reading this post, you should be familiar with the previous chapters:

1. [**Why Coordinate Frames Matter**](/posts/coordinates-frames/){:target="_blank"}
2. [**Why Body Frames Matter**](/posts/body-frames/){:target="_blank"}
3. [**Earth Coordinates**](/posts/earth-coordinates/){:target="_blank"}
4. [**Local Tangent Plane**](/posts/local-tangent-plane/){:target="_blank"}

## Introduction

Sensors never measure the world in a global reference frame, they measure what
they see relative to their own frame. However, navigation, tracking and sensor fusion requires
that all observations are on the common frame.

Without transforming the sensors observations into the common frame, we cannot:

- Combine measurements from multiple sensors
- Track a target's position over time
- Estimate motion
- Perform multi-sensor fusion

These coordinates transformations are the gap between what each sensors see and what we need
to know to navigate, track and make decisions. Without them, each sensor observation is
isolated in its [**own frame**](/posts/body-frames/){:target="_blank"}. Without transforming all of these measurements
into a common frame,
like [**ENU or NED**](/posts/local-tangent-plane/){:target="_blank"}, we could never determine where the target really
is, how it is moving, or predict its future position.

### Body-Frame Measurements

![frd](/assets/img/navigation/body-frames/frd.png){: width="640" }

---

- IMUs provide acceleration and angular velocity
- Cameras detect pixels relative to their optical center
- Radars measure range and bearing from their antenna

### Radar Spherical Coordinates

Radar is a classic example of a sensor that measures in its own body frame using spherical coordinates. But these
measurements
need to be transformed into a common frame to be useful.

![radar](/assets/img/navigation/coordinates-transformations/radar.gif){: width="300" }
<center><em>Figure 1: Radar</em></center>

---

{: .text-center}
_This was explained more in depth
in the [**Why Body Frames Matter**](/posts/body-frames/#what-is-an-spherical-coordinate){:target="_blank"} post._

## Bearing Conventions Used

We will follow **aviation and radar conventions** for spherical coordinates:

- **Azimuth:** Horizontal angle measured clockwise from North
    - 0° = North
    - 90° = East
    - 180° = South
    - 270° = West
- **Elevation:** Vertical angle measured from the horizontal plane
    - 0° = parallel to ground
    - +90° = straight up
    - -90° = straight down

- **Range:** Distance in meters from the sensor to the target

## Why Origins Matter

It's not enough to know the direction of the measurement, you must also know where the sensor is located
in a reference frame, two identical bearings can correspond to very different target positions depending on the
sensor’s origin:

- The sensor is at the origin of the [**ENU**](/posts/local-tangent-plane/#east-north-up-enu){:target="_blank"} frame
- The sensor is located at 2km east (2000,0,0)
- The [**Local Tangent Plane (LTP)**](/posts/local-tangent-plane/){:target="_blank"} origin are different

_Coordinate systems differ not only by orientation but also by origin._

## Estimating Orientation and Velocity of a Moving Object

A radar station observes an unknown target at two different times:

- At time $$t_1$$: Bearing $$\theta_1$$, Azimuth $$\phi_1$$, range $$r_1$$
- At time $$t_2$$: Bearing $$\theta_2$$, Azimuth $$\phi_2$$, range $$r_2$$
- Time difference: $$\Delta t = t_2 - t_1$$

With these two observations, we can estimate:

$$
\text{When}: \\[6pt]
\begin{aligned}
p_1, p_2 \in \text{Frame} \\[6pt]
\end{aligned}
$$

### Velocity

$$velocity = \frac{\Delta p}{\Delta t}$$

---

<center><em><small><b>Notes</b></small></em></center>

<ul>
<li>
  <em><small>
      In the real world calculating velocity like this <b>amplifies sensor noise</b>, 
      this is why we need filters like <b><a href="https://en.wikipedia.org/wiki/Kalman_filter" target="_blank">Kalman filters</a></b> to smooth out these estimates.
</small></em>
</li>
</ul>

---

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

---

### Orientation

To calculate the **yaw** ($$\psi$$) and **pitch** ($$\theta$$) from the **velocity vector** ($$v$$), we use the
following formulas:

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
<em><small>In <b>ENU</b>, <b>Z</b> points up, so <b>pitch positive</b> means nose up.</small></em>
</li>
<li>
<em><small>In <b>NED</b>, the <b>Z</b> axis points Down. To maintain the convention that <b>positive pitch</b> corresponds to the nose pointing 
up, we must apply <b>-Z</b> in the <b>pitch</b> calculation</small></em>
</li>
<li>
<em><small>The function <b>atan2(y, x)</b> returns the <b>yaw</b> in the range <b>(-π, π)</b>, measured counter-clockwise from the positive X-axis.</small></em>
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

### Limitations of Position-Based Orientation Estimation

When estimating orientation from position changes, there are some limitations to consider:

**What We CAN Estimate:**

- **Yaw:** Derived from horizontal velocity components **(x, y)**
- **Pitch:** Derived from vertical velocity component **(z)** relative to horizontal plane

**What We CANNOT Estimate:**

- **Roll** cannot be measured from position observations alone and must be provided.

This is because **multiple roll angles produce the same trajectory**. Consider an aircraft:

- **Roll** = 0° flying straight
- **Roll** = 45° in coordinated turn

Both can produce identical position sequences, but the observations made by the aircraft will
differ.

**Solutions:**

1. **For External Tracking (radar observing target):**
    - Assume constraints based, for example, ground vehicles: roll = 0°
    - Use additional sensors if available

2. **For Own Navigation:**
    - Use IMU/gyroscopes for direct roll measurement
    - Combine accelerometers and magnetometers for attitude estimation
    - Apply sensor fusion techniques (covered in next chapter)

In our examples, we assume $$roll = 0^\circ$$ for **simplicity**, which is reasonable for:

- Ground vehicles on flat terrain
- Aircraft in straight and level flight
- Ships in calm seas

## First Problem: Estimating Target Position from Radar Observation

### Scenario Description

A radar observes a target in the sky, we want to determine where is the target in world coordinates. Also, we want to
estimate its velocity and orientation based on two observations separated by time.

![enu-observation](/assets/img/navigation/coordinates-transformations/enu-observation.gif)
<center><em>Figure 2: Radar Observation</em></center>

### Coordinate Transformation Pipeline

We need to know the **radar's global position** in
[**WGS84**](/posts/earth-coordinates/){:target="_blank"} and its orientation ( here **aligned** with **ENU** for
**simplicity** ).

We have seen how to transform a single observation from spherical to cartesian coordinates in the **radar's body
frame.**

1. Transform the **radar observation** into the **common frame**
2. Convert the observation into **world coordinates** using the radar's global position and orientation.
3. Estimate the **velocity** and **orientation** based on two observations.

![coordinate-transformation-pipeline](/assets/img/navigation/coordinates-transformations/coordinate-transformation-pipeline.png)
<center><em>Figure 3: Coordinate Transformation Pipeline</em></center>

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
  <em><small>The time of 2 seconds between observations is arbitrary for demonstration purposes. Therefore, it is not realistic</small></em>
</li>
</ul>

---

## Second Problem: Distributed Tracking

### Scenario Description

The second scenario involves two moving objects:

- An aircraft observed by a ground-based radar
- A car observed by the aircraft

We want to determine the car's position in the radar's ENU frame, based on observations from both the radar and the
aircraft.

![enu-multiple-observation](/assets/img/navigation/coordinates-transformations/enu-multiple-observation.gif)
<center><em>Figure 4: ENU Distributed Observation</em></center>

### Coordinate Transformation Pipeline

The pipeline to resolve the car's position in world coordinates involves multiple transformations:

1. Transform the **radar aircraft observation** into the **common frame**
2. Convert the observation into **world coordinates**
3. Create the **aircraft's local frame** based on its position and orientation
    1. When the aircraft moves, we need to update its origin
4. Transform the **aircraft car observation** into the **common frame**
5. Convert the observation into **world coordinates**
6. Finally, transform the car's world coordinates back into the **radar's ENU frame**
7. Estimate the **car's velocity** and **orientation** based on two observations.

![enu-multiple-observation](/assets/img/navigation/coordinates-transformations/distributed-pipeline.png)
<center><em>Figure 5: ENU Distributed Observation Pipeline</em></center>

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

    // Change aircraft origin to second observation to add a Translation, because the new observation is from a moving aircraft
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

After knowing the target's global position from previous observations, we want to point directly at it to track the
target. To do this, we need to calculate the bearing from its own position
to the target's, this allows the radar to aim precisely at the target in 3D space.

1. Convert the **world coordinate** into the local frame
2. Convert the **cartesian** into **spherical coordinates**

```rust
impl<System> Coordinate<System>
where
    System: CartesianSystem + BearingConversion,
{
    pub fn to_spherical(&self) -> SphericalCoordinate<System> {
        SphericalCoordinate::from(self)
    }

    pub fn bearing_from_origin(&self) -> Bearing<System> {
        let spherical = self.to_spherical();

        System::spherical_to_bearing(spherical.polar, spherical.azimuth)
    }
}

fn main() {
    // Continue from second example...
    let bearing_to_car_position_from_radar = car_position_in_radar_enu.bearing_from_origin();
    let car_position_distance = car_position_in_radar_enu.distance_from_origin();

    // Radar bearing to target: azimuth -98.276°, elevation -2.855°, range 306.4m
}
```

## Landmark Navigation

When you're in an **unknown location** and, you don’t know where you are, one method of knowing your position is by
**observing** known landmarks. By **measuring** the direction and distance to these landmarks, you can estimate your
position.

### Observing a Known Landmark

A **known landmark** is any object whose coordinates are already known, for example the **Sagrada Família**.

![landmark](/assets/img/navigation/coordinates-transformations/sagrada-familia.png)
<center><em><small>Figure 5: La Sagrada Familia, Barcelona, Spain </small></em></center>

### Convergence algorithm

Once you have observed a landmark, to estimate your global position, you can use an
iterative convergence algorithm.

You must have the following requisites:

- The landmark's global position is known in **world coordinates**
- Your observation of the landmark is expressed in your **local frame**
- The **orientation** of your local frame with respect to North and East

### Mechanism of the ECEF Correction

The convergence relies on using the **known position** of the landmark to **correct** our **unknown position**. Each
iteration
performs a **correction** in the **ECEF** frame:

- Calculate Estimated **Landmark world coordinate** ($$\mathbf{\hat{p}}_{\text{LM, ECEF}}$$)
- **Determine Error Vector**: The error vector is the difference between this
  calculated position and the known, true landmark
  position ($$\mathbf{p}_{\text{LM, ECEF}}$$).

$$\text{Error} = \mathbf{\hat{p}}_{\text{LM, ECEF}} - \mathbf{p}_{\text{LM, ECEF}}$$

- **Correct Observer Position**: By subtracting this error vector from our current world position
  estimation ($$\mathbf{p}_{\text{obs, ECEF}}^{\text{old}}$$), we shift our estimation closer to the true origin of the
  observation

$$\mathbf{p}_{\text{obs, ECEF}}^{\text{new}} = \mathbf{p}_{\text{obs, ECEF}}^{\text{old}} - \text{Error}$$

This process is repeated until the error vector is below a defined threshold or maximum iterations is reached.

---

```rust
pub struct LandmarkObservation<System> {
    pub(crate) position: Coordinate<System>,
    _system: std::marker::PhantomData<System>,
}

/// Convergence threshold in meters. 
/// 1e-6m = 1 micrometer is well below typical GPS error (1-3m),
/// so further refinement provides no practical benefit.
const CONVERGENCE_THRESHOLD: f64 = 1e-6;

/// Typically converges in 1-2 iterations for well-conditioned geometry.
/// If >3 iterations needed, geometry is likely poorly conditioned
/// (landmarks nearly collinear) or landmark position is wrong.
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

cartesian_system!(pub struct ObserverRFU using RFU);
cartesian_system!(pub struct ObserverENU using ENU);

fn main() {
    // Sagrada Familia wgs84 position
    let landmark = Landmark::new(
        Coordinate::<Wgs84>::new(
            Latitude::from_degrees(41.4036576).unwrap(),
            Longitude::from_degrees(2.1742631).unwrap(),
            Altitude::from_meters(46.5),
        ),
    );

    // Observer's measurement of the landmark in its local RFU frame
    let observation = Coordinate::<ObserverRFU>::from_bearing(
        Bearing::new(Azimuth::from_degrees(40.8), Elevation::from_degrees(0.0)),
        Length::new::<meter>(792.78),
    );

    // Observer's orientation: facing 140° from North in ENU frame
    let observer_orientation = Orientation::<ObserverENU>::from_tait_bryan(TaitBryanAngles::new(
        Roll::new(Angle::new::<degree>(0.0)),
        Pitch::new(Angle::new::<degree>(0.0)),
        Yaw::new(Angle::new::<degree>(140.0)),
    ));

    let transform_observer_enu_to_rfu = RigidBodyTransform::enu_to_rfu(observer_orientation);

    let landmark_in_observer_ned = transform_observer_enu_to_rfu.inverse_transform(observation);

    let landmark_observation = LandmarkObservation::new(landmark_in_observer_ned);

    let estimated_observer_global_position =
        landmark_observation.estimate_observer_global_position(&landmark);

    // estimated observer_global_position: 41.41079504087482°N, 2.1743954712480287°E, 46.450616201111075m
    println!(
        "estimated observer_global_position: {}",
        estimated_observer_global_position
    );
}
```

--- 

![estimated-distance-landmark](/assets/img/navigation/coordinates-transformations/estimated-distance.png){: width="
640" }
<center><em><small>Figure 7: Estimated position </small></em></center>

---

**Note on Landmark Geometry:** The accuracy of the estimation from landmarks depends on their geometry. This is
quantified by the
[**Geometric Dilution of Precision (GDOP)**](https://en.wikipedia.org/wiki/Dilution_of_precision){: target="_blank"}
metric.

---

## Applications of Target Estimations

Once we have these data, we have tons of applications:

1. **Sensor Fusion**  
   By converting all sensor measurements to a common frame, we can combine information from
   multiple sources.

2. **Tracking and Prediction**  
   Knowing the velocity and orientation of moving targets allows us to predict their future positions, which is crucial
   for collision avoidance, autonomous navigation, and air/ground traffic monitoring.

3. **Target Identification**  
   Comparing positions, velocities, and orientations over time can help determine whether observations at different
   times correspond to the same object. This is essential for tracking multiple targets simultaneously.

4. **Engagement and Control**  
   Converting global target positions into local azimuth, elevation, and range allows platforms to aim sensors or
   communication systems accurately.

5. **Relative Navigation**  
   If the absolute position of the observer is uncertain, using landmarks or other targets allows iterative refinement
   of our global position estimate.

---

## Limitations and Sources of Error

While these estimations are useful, there are some important considerations:

- **Sensor Noise:** All sensors have measurement errors and biases which propagate through coordinate transformations.
- **Timing Errors:** Small differences in timestamps can lead to large errors in velocity and orientation estimation.
- **Frame Misalignment:** Assuming incorrect orientation or origin for the sensor can lead to large errors in target
  position.

---

## So What’s Next?

To mitigate these errors, we need advanced filtering techniques. The
[**Kalman Filter**](https://en.wikipedia.org/wiki/Kalman_filter){: target="_blank"} is an algorithm that allows us to:

- **Fuse noisy measurements** from multiple sensors
- **Estimate** variables
- **Predict future** positions

In the next post, we’ll dive into **Kalman Filtering and Multi-Sensor Fusion**, showing how to combine radar, camera,
and **IMU** data to track our own position and moving targets with high accuracy.
