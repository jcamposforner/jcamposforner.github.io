---
title: "Navigation Systems: Local Tangent Plane"
description: "A Local Tangent Plane (LTP) is a coordinate frame that approximates the Earth's surface as flat in a small
area around a specific point. Learn how LTPs are used in navigation to simplify calculations and represent positions and
orientations relative to the Earth's surface."
categories: [ Navigation, Local Tangent Planes, Coordinate Frames, Earth ]
tags: [ Navigation, Coordinate Systems, Reference Frames, Earth Coordinates, Earth, NED, Orientation, Position, Geospatial ]
hidden: false
math: true
read_complexity: 1.5
---

Before reading this post, make sure you’re familiar with the previous chapters in this series, as they establish the
foundations for frames, navigation, and orientation:

1. [**Why Coordinate Frames Matter**](/posts/coordinates-frames/){:target="_blank"}
2. [**Why Body Frames Matter**](/posts/body-frames/){:target="_blank"}
3. [**Earth Coordinates**](/posts/earth-coordinates/){:target="_blank"}

## Introduction

A **Local Tangent Plane (LTP)** approximates the Earth's surface as flat around a specific point. This simplification
allows
navigation systems to compute distances, directions, and orientations easily within small areas, typically within a few
kilometers. LTPs are widely used in UAV missions, autonomous vehicles, marine operations, and surveying.

## What Is a Local Tangent Plane?

Local Tangent Planes **(LTP)** describes coordinates relative to a tangent plane of a spatial reference system **at a
particular point**, within a few kilometers of this origin, the Earth can be approximated as flat. Thanks to working
with
cartesian coordinates in a flat plane, LTPs simplify the calculations.

To obtained the LTP we need to project global coordinates onto a plane tangent to the reference ellipsoid at a chosen
latitude and longitude.

## Types of LTP

There are two common LTP conventions, **North-East-Down (NED)** and **East-North-Up (ENU)**. Both are right-handed
cartesian
coordinate systems, so we can apply the **[previous concepts](/categories/navigation/){:target="_blank"}**
we learned about these systems.

### North-East-Down (NED).

Common in **aviation** and **maritime** navigation.

- **X-axis (North):** points toward geodetic north
- **Y-axis (East):** points toward geodetic east
- **Z-axis (Down):** points toward the center of the Earth

In an airplane, most objects of interest are below the aircraft. Using NED makes it easier to represent these objects.

![ned](/assets/img/navigation/local-tangent-plane/ned.png)

---

### East-North-Up (ENU).

Common in **land** navigation and **surveying**.

- **X-axis (East):** points toward geodetic east
- **Y-axis (North):** points toward geodetic north
- **Z-axis (Up):** points away from the Earth’s center

On the ground, most objects of interest are **above** or **at same level** as the observer. Using ENU makes it easier to
represent these objects.

![enu](/assets/img/navigation/local-tangent-plane/enu.png)

---

### Which One to Use?

There are no final answer, you should choose the convention that makes the most sense for your application and domain.

## LTP Origin

The **origin** of an LTP is defined by a reference geodetic coordinate. It determines where the tangent plane
touches the Earth's surface.

For example, a **[vehicle’s body frame](/posts/body-frames/){:target="_blank"}** can be expressed relative to an LTP
origin, allowing its **position and attitude** to be represented in a local reference frame.

## LTP Orientation

The orientation of a LTP is defined by how its axes are aligned relative to the Earth’s surface at the origin. Each axis
pointing to the geodetic directions **(North, East, Up/Down)** at that point.

Imagine the LTP as a flat sheet of paper resting on the Earth at the origin.

![compass](/assets/img/navigation/local-tangent-plane/compass.png)

## Why won't we always use LTP?

Well... when we are navigation over large distances, the **curvature** of the Earth becomes significant. **LTPs** are
only accurate for small areas, typically within a **few kilometers** of the **origin**. Beyond this range, errors due to
the **Earth's curvature** can accumulate, leading to **inaccurate position** and orientation estimates.

Imagine a straight line originating from the origin of the Local Tangent Plane (LTP). As we move farther from the
origin, the Earth's surface curves away from this line, so the line no longer follows the surface and extends to the
inertial space.

![straight-line](/assets/img/navigation/local-tangent-plane/straight-line-ltp.png)

To maintain accuracy, we need to add a **threshold** for when to switch the LTP origin, the **sagitta** helps us to
determine when the error becomes significant for a given application, especially for
**inertial navigation systems (INS)**, where small position errors can quickly grow over time.

### Sagittal Height Error

The **[sagitta](https://en.wikipedia.org/wiki/Sagitta_(geometry)){:target="_blank"}** is the **height difference**
between
the **Earth's** curved surface and the tangent plane over a chord length $$c$$

**The sagitta ($$s$$) can be calculated using the formula:**

$$
\begin{aligned}
s & = r - \sqrt{r^2 - \left(\frac{c}{2}\right)^2} \\
\end{aligned}
$$

**where:**

- $$r$$ is the radius of the Earth

**and:**

- $$c$$ is the chord length, representing the distance from the LTP origin to the point of interest

for small distances, we can approximate the sagitta using:

$$
\begin{aligned}
s & \approx \frac{c^2}{8r} \\
\end{aligned}
$$

### Seeing the Limits of the LTP

For a chord length ($$c = 10,000 \text{ m}$$) and an average Earth radius of $$r = 6,371,000 \text{ m}$$:

$$
\begin{aligned}
s & \approx \frac{(10,000 \text{ m})^2}{8 \times 6,371,000 \text{ m}} \\
& \approx 1.96 \text{ m} \\
\end{aligned}
$$

The difference between the approximate and the exact sagitta is negligible for small distances. In this scenario, the
error using both formulas is $$3.01 \times 10^{-7}\ \text{m}$$

| Distance (m) | Sagitta (m) |
|--------------|-------------|
| 100          | 0.00019     |
| 1,000        | 0.19        |
| 10,000       | 1.96        |
| 50,000       | 48.99       |

{: style="margin-left: auto; min-width:100%; margin-right: auto; text-align: center;"}

```rust
pub struct Sagitta;

impl Sagitta {
    const SMALL_DISTANCE_THRESHOLD: f64 = 50_000.0;

    pub fn calculate<System>(
        p1: Coordinate<System>,
        p2: Coordinate<System>,
        radius: Length,
    ) -> Length
    where
        System: CartesianSystem,
    {
        let chord_length = (p2.to_point() - p1.to_point()).norm();
        let radius_m = radius.get::<meter>();

        let sagitta_length = if chord_length < Sagitta::SMALL_DISTANCE_THRESHOLD {
            chord_length.powi(2) / (8.0 * radius_m)
        } else {
            radius_m - ((radius_m.powi(2) - (chord_length / 2.0).powi(2)).sqrt())
        };

        Length::new::<meter>(sagitta_length)
    }

    pub fn approx<System>(p1: Coordinate<System>, p2: Coordinate<System>) -> Length
    where
        System: CartesianSystem,
    {
        let radius = Length::new::<meter>(earth_constants::SEMI_MAJOR_AXIS);

        Sagitta::calculate(p1, p2, radius)
    }

    pub fn approx_origin<System>(p1: Coordinate<System>) -> Length
    where
        System: CartesianSystem,
    {
        Sagitta::approx(p1, Coordinate::<System>::origin())
    }
}

fn main() {
    Sagitta::approx_origin::<Ned>(Coordinate::<Ned>::new(10_000.0, 0.0, 0.0)); // ≈ 1.96 m
}
```

![sagitta](/assets/img/navigation/local-tangent-plane/sagitta.png)

---

For a more precise radius on the **WGS84 ellipsoid**, we can use
the **[geocentric radius](https://en.wikipedia.org/wiki/Earth_radius#Geocentric_radius){:target="_blank"}** to get
the $$r$$ value in a given latitude ($$\phi$$):

The geocentric radius is the distance from the Earth's center to a point on the spheroid surface at geodetic
latitude $$\phi$$, given by the formula

$$
\begin{aligned}
r(\phi) & = \sqrt{\frac{(a^2 \cos(\phi))^2 + (b^2 \sin(\phi))^2}{(a \cos(\phi))^2 + (b \sin(\phi))^2}} \\
\end{aligned}
$$

```rust
impl Wgs84 {
    pub fn geocentric_radius(&self) -> Length {
        let lat = self.get::<radian>();
        let a = earth_constants::SEMI_MAJOR_AXIS;
        let b = earth_constants::SEMI_MINOR_AXIS;

        let sin_lat = lat.sin();
        let cos_lat = lat.cos();

        let numerator = ((a.powi(2) * cos_lat).powi(2) + (b.powi(2) * sin_lat).powi(2)).sqrt();
        let denominator = ((a * cos_lat).powi(2) + (b * sin_lat).powi(2)).sqrt();

        Length::new::<meter>(numerator / denominator)
    }
}
```

---

## Converting Between LTP and Global Coordinates

To convert from global coordinates like **WGS84** to **LTP** coordinates, we need to convert the global coordinates to
**ECEF** coordinates, then we can convert from
**ECEF** to **LTP**. We have to rotate and translate the coordinates based on the **LTP** origin.

### ENU rotation matrix

$$
R_{\text{ECEF→ENU}} =
\begin{bmatrix}
-\sin\lambda & \cos\lambda & 0 \\
-\sin\phi\cos\lambda & -\sin\phi\sin\lambda & \cos\phi \\
\cos\phi\cos\lambda & \cos\phi\sin\lambda & \sin\phi
\end{bmatrix}
$$

---

```rust
impl<To> RigidBodyTransform<ECEF, To>
where
    To: CartesianSystem<CoordinateKind=ENULike>,
{
    pub fn wgs84_to_enu(wgs84: &Coordinate<Wgs84>) -> Self {
        let ecef = wgs84.to_ecef();
        let translation = Translation::from(ecef);
        let rotation = Rotation::ecef_to_enu_at(wgs84);

        RigidBodyTransform::new(translation, rotation)
    }
}

impl<To> Rotation<ECEF, To>
where
    To: CartesianSystem<CoordinateKind=ENULike>,
{
    pub fn ecef_to_enu_at(coordinate: &Coordinate<Wgs84>) -> Self {
        let phi = coordinate.latitude.get::<radian>();
        let lambda = coordinate.longitude.get::<radian>();

        let sin_phi = phi.sin();
        let cos_phi = phi.cos();
        let sin_lambda = lambda.sin();
        let cos_lambda = lambda.cos();

        let matrix = Matrix3::new(
            -sin_lambda,
            -cos_lambda * sin_phi,
            cos_lambda * cos_phi,
            cos_lambda,
            -sin_lambda * sin_phi,
            sin_lambda * cos_phi,
            0.,
            cos_phi,
            sin_phi,
        );

        let rot = crate::Rotation::from_matrix(&matrix);
        let quaternion = UnitQuaternion::from_rotation_matrix(&rot);

        Self {
            inner: quaternion,
            _from: std::marker::PhantomData,
            _to: std::marker::PhantomData,
        }
    }
}
```

### NED rotation matrix

$$
R_{\text{ECEF→NED}} =
\begin{bmatrix}
-\sin\phi\cos\lambda & -\sin\phi\sin\lambda & \cos\phi \\
-\sin\lambda & \cos\lambda & 0 \\
-\cos\phi\cos\lambda & -\cos\phi\sin\lambda & -\sin\phi
\end{bmatrix}
$$

---

```rust
impl<To> RigidBodyTransform<ECEF, To>
where
    To: CartesianSystem<CoordinateKind=NEDLike>,
{
    pub fn wgs84_to_ned(wgs84: &Coordinate<Wgs84>) -> Self {
        let ecef = wgs84.to_ecef();
        let translation = Translation::from(ecef);
        let rotation = Rotation::ecef_to_ned_at(wgs84);

        RigidBodyTransform::new(translation, rotation)
    }
}

impl<To> Rotation<ECEF, To>
where
    To: CartesianSystem<CoordinateKind=NEDLike>,
{
    pub fn ecef_to_ned_at(coordinate: &Coordinate<Wgs84>) -> Self {
        let phi = coordinate.latitude.get::<radian>();
        let lambda = coordinate.longitude.get::<radian>();

        let sin_phi = phi.sin();
        let cos_phi = phi.cos();
        let sin_lambda = lambda.sin();
        let cos_lambda = lambda.cos();

        let matrix = Matrix3::new(
            -cos_lambda * sin_phi,
            -sin_lambda,
            -cos_lambda * cos_phi,
            -sin_lambda * sin_phi,
            cos_lambda,
            -sin_lambda * cos_phi,
            cos_phi,
            0.,
            -sin_phi,
        );

        let rot = crate::Rotation::from_matrix(&matrix);
        let quaternion = UnitQuaternion::from_rotation_matrix(&rot);

        Self {
            inner: quaternion,
            _from: std::marker::PhantomData,
            _to: std::marker::PhantomData,
        }
    }
}
```

### NED to ENU

Also, we can convert between NED and ENU frames inverting the axes as follows:

$$
R_{\text{NED↔ENU}} =
\begin{bmatrix}
0 & 1 & 0 \\
1 & 0 & 0 \\
0 & 0 & -1
\end{bmatrix}
$$

---

```rust
fn reorient_right_hand_axes() -> UnitQuaternion {
    let matrix = Matrix3::new(0., 1., 0., 1., 0., 0., 0., 0., -1.);
    let rot = crate::Rotation::from_matrix(&matrix);

    UnitQuaternion::from_rotation_matrix(&rot)
}
```

### LTP Example: UAV Mapping Mission

Imagine an **UAV** performing a **mapping mission** over a test area. The **UAV** starts at a known location defined by
its **WGS84**
coordinates. As it **flies 2 km north**, we want to track its position in a LTP centered at
its starting point and objectives.

During the mission, the **UAV detects an object 2 km north, 100 meters east and same altitude relative to its local
frame**. While local coordinates simplify navigation and sensor fusion, the UAV must **convert** the observation back to
**global WGS84 coordinates** to report it to a ground station or log it in a global map.

<img src="/assets/img/navigation/local-tangent-plane/uav-example.png" alt="uav-example" style="max-width: 600px; width: 450px; height: auto;">

---

To start the mission, we define the LTP origin using the UAV initial WGS84 coordinates:

```rust
fn drone_mission() {
    let uav_origin_wgs84 = Coordinate::<Wgs84>::new(
        Latitude::from_degrees(51.5073507).unwrap(),
        Longitude::from_degrees(-0.088129).unwrap(),
        Altitude::from_meters(100.0),
    );

    let ecef_to_ned = RigidBodyTransform::wgs84_to_ned(&uav_origin_wgs84);

    let observation_local = Coordinate::<DroneNED>::new(2000.0, 100.0, 0.0);
    let observation_ecef = ecef_to_ned.inverse_transform(observation_local);
    let observation_wgs84 = observation_ecef.to_wgs84();

    println!("UAV origin in: {}", uav_origin_wgs84);
    println!("UAV observation in: {}", observation_wgs84);
    println!(
        "UAV distance: {}",
        observation_wgs84
            .haversine_distance(&uav_origin_wgs84)
            .get::<meter>()
    );

    // UAV origin in: 51.5073507°N, 0.08812900000000079°W, 100m
    // UAV observation in: 51.52532662050738°N, 0.08668814239330849°W, 100.31452162163544m
    // UAV distance: 2003.56m ( sqrt(2000^2 + 100^2) )
}
```

## When LTPs Shine: Real-World Applications

### Autonomous Vehicle Navigation

A self-driving car navigating a 5km test track doesn't need to worry about Earth's curvature. With a sagitta error of
only ~0.5m over this distance, the LTP provides precision for lane keeping, obstacle detection, and
path planning. The car's sensors report positions in meters relative to the track origin.

### Agricultural Drone Mapping

A drone surveying a 2x2 km farm plots its coverage in a NED frame centered on the field corner. The approximately 0.16m
sagitta error is insignificant compared to the drone's GPS accuracy (±1-5m). This local reference makes it trivial to
generate orthomosaic maps, calculate crop rows, and identify problem areas without complex geodetic transformations.

And much more:

- **Maritime Navigation**: Ships operating within coastal waters can use LTPs for accurate navigation and collision
  avoidance.
- **Surveying and Mapping**: Surveyors can use LTPs for high-precision measurements over small areas.
- **UAV Operations**: Drones conducting inspections or deliveries in urban environments benefit from LTPs for precise
  positioning.
- **Robotics**: Robots operating in warehouses or factories can use LTPs for accurate navigation and task execution.
- **Mapping areas**:* LTPs are ideal for mapping small regions.

**LTPs excel** when your **operational area is small enough** that Earth's curvature introduces less error than
your sensors' inherent accuracy.

## So What's Next?

By now you have seen why **Local Tangent Planes (LTPs)** are essential for **simplifying** navigation calculations over
small
areas. They allow us to approximate the Earth's surface as flat, making it easier to compute distances, directions, and
orientations. However, remember that **LTPs are only accurate for small areas**, typically within a **few kilometers**
of the
origin. Beyond this range, the **Earth's curvature** becomes significant, and we need to **switch** to global coordinate
systems
like WGS84 for **accurate navigation**.

In the next post, **we’ll bring it all together: body frames, LTPs, WGS84, and sensor observations**, showing how
multiple
coordinate frames can be combined to solve complex navigation problems involving UAVs, ships, or land vehicles. You’ll
see how local and global perspectives work together in real-world scenarios.