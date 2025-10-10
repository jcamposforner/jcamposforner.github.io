---
title: "Navigation Systems: Geodetic Coordinates"
description: "Understanding Earth's coordinate reference frames: WGS84 ellipsoid modeling, geodetic vs ECEF coordinates, and implementations for converting between them."
categories: [ Navigation, Geodetic Coordinates, Coordinate Frames, Earth ]
tags: [ Navigation, Coordinate Systems, Reference Frames, Earth Coordinates, Earth, NED, Orientation, Position, Geospatial ]
hidden: false
math: true
read_complexity: 2
---

![earth](/assets/img/navigation/geodetic/earth.png)

## Understanding Earth's Coordinate Reference Frames

Before we can start talking about local tangent planes like **NED** or **ENU**, which need to be aligned with magnetic
or true north, we first need to understand how the Earth is modeled.

Earth isn't a perfect sphere, it's an **oblate spheroid**, slightly flattened at the poles and bulging at the equator.
This shape is best represented by the **WGS84 ellipsoid**, which
provides a mathematical representation of the Earth's surface.

Even the ellipsoid isn’t a perfect match for reality. The true shape of the Earth is a **geoid**, which accounts for
local
variations in terrain, such as mountains, valleys, and other geological features. **Geoid** models provide a more
accurate
representation of Earth’s gravitational field and surface shape.

![earth-shapes](/assets/img/navigation/geodetic/earth-shape.png)
<center><em>Earth shapes</em></center>

--- 

Based on these concepts, the altitude can be defined in multiple ways:

- **Height above ellipsoid (HAE)**: The altitude measured from the WGS84 ellipsoid
  surface. This is the geometric height commonly output by GPS/GNSS receivers.
- **Height above mean sea level (AMSL)**: The altitude measured from the geoid
  (mean sea level), which varies globally based on gravitational variations.
- **Height above ground level (AGL)**: The altitude measured from the local ground
  surface directly below the point of interest.

We'll focus on **HAE**, since it's the standard height used by most GPS/GNSS systems.

![earth](/assets/img/navigation/geodetic/earth-altitude.png)
<center><em>Earth altitude</em></center>

---

To model the Earth as an ellipsoid, we need to define a few key parameters that describe its size and shape:

<table style="width: 100%; overflow: hidden;">
  <thead>
    <tr>
      <th>Symbol</th>
      <th>Name</th>
      <th>Formula / Definition</th>
      <th>Value (m)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>\( a \)</td>
      <td>Semi-major axis</td>
      <td>Given</td>
      <td><strong>6 378 137.0</strong></td>
    </tr>
    <tr>
      <td>\( f \)</td>
      <td>Flattening</td>
      <td>\( 1 / 298.257223563 \)</td>
      <td><strong>0.0033528106647474805</strong></td>
    </tr>
    <tr>
      <td>\( b \)</td>
      <td>Semi-minor axis</td>
      <td>\( a(1 - f) \)</td>
      <td><strong>6 356 752.314245179</strong></td>
    </tr>
    <tr>
      <td>\( e^2 \)</td>
      <td>Eccentricity squared</td>
      <td>\( 2f - f^2 \)</td>
      <td><strong>0.0066943799901413165</strong></td>
    </tr>
    <tr>
      <td>\( R_\text{mean} \)</td>
      <td>Mean radius</td>
      <td>\( \dfrac{2a + b}{3} \)</td>
      <td><strong>6 371 008.771415059</strong></td>
    </tr>
  </tbody>
</table>

<img src="/assets/img/navigation/geodetic/earth-radius.png" alt="earth-radius" style="max-width: 600px; width: 100%; height: auto;">
<center><em>Earth ellipsoid</em></center>

--- 
With these parameters, we can define the ellipsoid and perform various calculations, such as converting between
geodetic coordinates and Cartesian coordinates. These transformations are essential for GPS positioning, navigation,
and integrating local coordinate systems.

## Geodetic Coordinates

### What Are Geodetic Coordinates?

Geodetic coordinates are a way to describe positions similar to spherical coordinate system. They consist of three
values:

- **Latitude ($$\phi$$)**: The angle north or south of the equator (**-90°** to **+90°**)
- **Longitude ($$\lambda$$)**: The angle east or west of the Prime Meridian (**-180°** to **+180°**)
- **Altitude ($$h$$)**: Already mentioned earlier as height above the **WGS84** ellipsoid (HAE)

This system is intuitive for humans and easy to share, which is why maps often use it.

<img src="/assets/img/navigation/geodetic/lat-lon.png" alt="latitude-longitude" style="max-width: 600px; width: 100%; height: auto;">
<center><em>Latitude and Longitude</em></center>

--- 

### Why We Use Geodetic Coordinates

Geodetic coordinates are convenient and human-readable, but they come with some limitations:

1. **Non-linear distance relationships**: The distance represented by a degree of $$\phi$$ or $$\lambda$$ changes
   depending on your location. For example, one degree of $$\lambda$$ is about **111 km at the equator** but
   close to **zero at the poles**
2. **Complex mathematical operations**: Calculating distances, bearings, or areas on the curved Earth is more
   complicated than using Cartesian coordinates
3. **Difficult to integrate with local frames**: Geodetic coordinates don’t naturally align with local navigation
4. **Singularities at the poles**: $$\phi$$ and $$\lambda$$ become **undefined** at the poles, complicating calculations
   in
   those areas

Because of these issues, geodetic coordinates are often converted to **Cartesian coordinates** for computation and
converted
back for sharing them.

## Cartesian Coordinates (X, Y, Z)

### Why we use Cartesian Coordinates

Cartesian coordinates represent several advantages over geodetic coordinates:

1. **Exact distances**: Calculating the distance between two points is straightforward using the Pythagorean theorem.
2. **Vector operations**: Addition, subtraction, and dot/cross products are simple and intuitive.
3. **Intuitive units**: Distances are measured in meters instead of degrees, making them easier to interpret
4. **Orientation**: We can know the direction of vectors in space using angles like **roll, pitch, and yaw**
5. **Transformations**: Points can be rotated or translated easily using matrix operations

But they also have disadvantages:

1. **Less human-readable**: They are not human-readable or easy to share
2. **Less intuitive on a sphere**: They can be less intuitive for representing locations on a spherical surface
3. **Dependence on origin and orientation**: They require a defined origin and orientation

For Earth navigation, the two most commonly used Cartesian systems are **ECEF** and **ECI**.

### Earth-Centered Inertial Frame

<img src="/assets/img/navigation/geodetic/eci.png" alt="eci" style="max-width: 600px; width: 100%; height: auto;">
<center><em>ECI</em></center>

---

In physics, any coordinate frame that does not **accelerate** or **rotate** is considered inertial. The ECI frame is
centered at the Earth's center of mass and oriented with respect to distant stars. This is not strictly inertial because
the Earth experiences acceleration in its orbit around the Sun. However, these effects are small for most
navigation systems.

The **Z-axis** always points along the Earth's rotation axis towards
the [North Celestial Pole](https://en.wikipedia.org/wiki/Celestial_pole){:target="_blank"}.
The **X-axis** points lies on the
equatorial plane pointing towards the [vernal equinox](https://en.wikipedia.org/wiki/March_equinox){:target="_blank"} (
the direction of the Sun at the March equinox, currently it points to **Pisces** constellation). The **Y-axis** is
just perpendicular to X-axis to complete the right-handed coordinate system.

<img src="/assets/img/navigation/geodetic/heliocentric-coordinate-system.png" alt="heliocentric" style="max-width: 600px; width: 100%; height: auto;">
<center><em>Heliocentric Coordinate System</em></center>

---

The [celestial equator](https://en.wikipedia.org/wiki/Celestial_equator){:target="_blank"} is a plane on the
[celestial sphere](https://en.wikipedia.org/wiki/Celestial_sphere){:target="_blank"}, due to
Earth's [axial tilt](https://en.wikipedia.org/wiki/Axial_tilt){:target="_blank"},
it is currently inclined about 23.44º with respect to the ecliptic.

<img src="/assets/img/navigation/geodetic/axial-tilt.png" alt="axial-tilt" style="max-width: 600px; width: 100%; height: auto;">
<center><em>Planets Axial Tilt</em></center>

---

With the known **Earth rotational axis**, we can determine the positions of the **North and South Celestial Poles** by
**extending the axis of rotation indefinitely** into space, the **North Celestial Pole (NCP)** is the point where the
Earth's rotation axis intersects the celestial sphere in the northern hemisphere, while the
**South Celestial Pole (SCP)** is the intersection in the southern hemisphere, which has no bright star but marks the
southern rotational axis direction, and these poles, being nearly fixed relative to distant stars, serve as **reference
points** for celestial coordinates, navigation, and defining the **Z-axis of the ECI frame**.

<img src="/assets/img/navigation/geodetic/celestial-sphere.png" alt="heliocentric" style="max-width: 600px; width: 100%; height: auto;">
<center><em>Celestial Sphere</em></center>

---

To orient ourselves in the ECI frame, we need to talk
about [Sidereal time](https://en.wikipedia.org/wiki/Sidereal_time){:target="_blank"}, the time is
**based on Earth's rotation relative to the stars** instead of the Sun, a sidereal day is approximately
**23 hours 56 minutes 4 seconds**. This is essential in space navigation because it allows us to point accurately toward
specific celestial coordinates.

The standard reference epoch **J2000.0** corresponds to **January 1, 2000, at 12:00 TT (Terrestrial Time)**, is used as
a
**standard reference instant** for celestial coordinates, ensuring that positions of stars, planets, and other celestial
objects remain consistent despite Earth's [precession](https://en.wikipedia.org/wiki/Axial_precession){:target="_blank"}
and [nutation](https://en.wikipedia.org/wiki/Astronomical_nutation){:target="_blank"}.

<img src="/assets/img/navigation/geodetic/axial-precession.gif" alt="precession" style="max-width: 600px; width: 100%; height: auto;">
<center><em>Axial Precession</em></center>

### Earth-Centered, Earth-Fixed Frame

ECEF is similar to ECI, except that all axes remain fixed with respect to the Earth and rotate with it. This removes the
astronomical complexity, making it much easier to work with positions on or near the Earth's surface.

The **Z-axis** points through the North Pole, the **X-axis** intersects the equator at the Prime Meridian (0°
longitude).
The **Y-axis** is perpendicular to both, completing the right-handed coordinate system.

<img src="/assets/img/navigation/geodetic/ecef-square.png" alt="ecef-square" style="max-width: 600px; width: 100%; height: auto;">
<center><em>Earth Cartesian Coordinates</em></center>

### Comparing ECI and ECEF Frames

**Use ECI when:**

- You’re analyzing how satellites move in space
- You need accurate motion without rotational effects
- You’re simulating or predicting orbits

**Use ECEF when:**

- You’re dealing with positions on or near Earth’s surface
- You need ground-relative positions or directions
- You’re computing GPS coordinates
- You’re performing radar or communication tracking from Earth
- Essentially, for anything that stays fixed to the planet

## GPS Positioning in ECEF

GPS positioning is fundamentally a geometry problem solved through **trilateration** to determine position.

### The Signal Propagation Problem

GPS satellites continuously broadcast two pieces of information:

1. **Ephemeris data**: Their precise orbital position at transmission time
2. **Timestamp**: The exact transmission time from onboard atomic clocks

Your receiver calculates the distance to each satellite using:

$$
\text{distance} = c \times (t_{\text{receive}} - t_{\text{transmit}})
$$

where $$c = 299{,}792{,}458$$ m/s (speed of light).

> **Precision matters**: A 1 nanosecond timing error produces 30 cm of position error. A 1 microsecond error
> produces 300 meters of position error.

### The Geometric Constraint

Each distance measurement defines a sphere centered on the satellite. Your position lies somewhere on that sphere's
surface.

![trilateration](/assets/img/navigation/geodetic/trilateration.png)
<center><em>Satellite trilateration</em></center>

---

- **1 satellite**: You're somewhere on a sphere around it
- **2 satellites**: You're on the circle where the two spheres intersect
- **3 satellites**: You're at one of two points where three spheres intersect
- **4 satellites**: Needed to solve for your receiver’s clock error

### Why Four Satellites Are Mandatory

If your receiver had a perfect clock synchronized with GPS time, you'd solve:

$$
\begin{aligned}
\sqrt{(x - x_1)^2 + (y - y_1)^2 + (z - z_1)^2} &= d_1 \\
\sqrt{(x - x_2)^2 + (y - y_2)^2 + (z - z_2)^2} &= d_2 \\
\sqrt{(x - x_3)^2 + (y - y_3)^2 + (z - z_3)^2} &= d_3
\end{aligned}
$$

Three equations, three unknowns (x, y, z), that should be enough to know your location, but your
receiver's clock isn't perfectly synchronized with the satellites. This timing error throws
off every distance measurement by $$c \times \Delta t$$. So now you need to solve:

$$
\begin{aligned}
\sqrt{(x - x_1)^2 + (y - y_1)^2 + (z - z_1)^2} &= d_1 + c \times \Delta t \\
\sqrt{(x - x_2)^2 + (y - y_2)^2 + (z - z_2)^2} &= d_2 + c \times \Delta t \\
\sqrt{(x - x_3)^2 + (y - y_3)^2 + (z - z_3)^2} &= d_3 + c \times \Delta t \\
\sqrt{(x - x_4)^2 + (y - y_4)^2 + (z - z_4)^2} &= d_4 + c \times \Delta t
\end{aligned}
$$

Four equations, four unknowns $(x, y, z, \Delta t)$. The fourth satellite allows the receiver to correct timing errors.

### Why ECEF Coordinates

Notice the equations above use Cartesian coordinates $(x, y, z)$. The distance formula is **Pythagorean theorem** in 3D,
because attempting trilateration in **WGS84** is more complex and non-linear. The math becomes much more
complex and computationally heavy.

This is why understanding coordinate transformations matters: GPS satellites provide positions in ECEF coordinates, and
your receiver must convert them to **WGS84**.

## Converting Between Coordinate Systems

### Transforming Geodetic to ECEF

Now that we’ve defined our ellipsoid, we can convert between the curved surface and the cartesian frame (X, Y, Z). This
is
essential for GPS, sensor fusion, and orbital mechanics.

The conversion formulas are:

$$
\begin{aligned}
X &= (N(\phi) + h) \cos\phi \cos\lambda \\
Y &= (N(\phi) + h) \cos\phi \sin\lambda \\
Z &= \left((1 - e^2)N(\phi) + h\right) \sin\phi
\end{aligned}
$$

where:

$$
N(\phi) = \frac{a}{\sqrt{1 - \frac{e^2}{1+\cot^2\phi}}}
$$

and:

$$
\cot^2 \phi = 1 / \tan(\phi)^2
$$

These formulas take into account the Earth’s flattening and give precise Cartesian coordinates for any point on or above
the ellipsoid.

![wgs84-ecef-conversion](/assets/img/navigation/geodetic/wgs84-to-ecef.png)
<p style="text-align: center;">
  <a href="https://en.wikipedia.org/wiki/Geographic_coordinate_conversion#From_geodetic_to_ECEF_coordinates" target="_blank">
    <em>More details on geodetic &lt;-&gt; ECEF conversion</em>
  </a>
</p>

### Transforming ECEF to Geodetic

Converting from ECEF to geodetic is more complex due to the ellipsoidal shape of the Earth. There is no closed-form, so
all the algorithms are only approximations, and for
high precision, iterative methods to find the are used.

One commonly used algorithm is that developed by **Chanfang Shu** and **Fei Li** (2010). It applies the
**Newton-Raphson** to refine the estimated $$\phi$$ and $$h$$ until convergence.

You can read the full paper here:
[View PDF](/assets/pdf/geodetic/an_iterative_algorithm_to_compute_geodet.pdf){:target="_blank"}

![ecef-wgs84-lon-conversion](/assets/img/navigation/geodetic/ecef-wgs84-lon.png)

![ecef-wgs84-conversion](/assets/img/navigation/geodetic/ecef-to-wgs84.png)

### Transforming ECI to ECEF

**Note:** This assumes the Z-axes of ECI and ECEF are aligned, which is false but a good approximation. See the note at
the
end for accuracy considerations.

$$
\theta = \text{ERA}_{J2000} + \omega_{\text{Earth}} \times \left( \frac{t_{\text{unix}} - t_{J2000}}{86400} \right)
$$

where:

- \\( \\omega_{\\text{Earth}} = 360.98564736629^\\circ/\\text{day} \\)
- \\( t_{J2000} = 946728000\ \\text{s} \\)
- \\( t_{\text{unix}} \\) — Unix timestamp of the observation

After computing ( $$\theta$$ ) in degrees, it is normalized and converted to radians:

To transform a position from the **Earth-Centered Inertial (ECI)** frame  
to the **Earth-Centered Earth-Fixed (ECEF)** frame, a **negative rotation** about the Z-axis is applied:

$$
\theta_{\text{rad}} = \left( \theta \bmod 360 \right) \times \frac{\pi}{180}
$$

$$
\mathbf{r}_{\text{ECEF}} =
\begin{bmatrix}
\cos\theta & \sin\theta & 0 \\
-\sin\theta & \cos\theta & 0 \\
0 & 0 & 1
\end{bmatrix}
\mathbf{r}_{\text{ECI}}
$$

![eci-ecef-conversion](/assets/img/navigation/geodetic/eci-to-ecef.png)

<img src="/assets/img/navigation/geodetic/eci_vs_ecef.gif" alt="earth-radius" style="max-width: 600px; width: 450px; height: auto;">
<center><em>ECEF and ECI axes comparison</em></center>

---

This is a good approximation, but technically wrong, ECI and ECEF do NOT have the Z axis aligned. They differ by the
**precession** and **nutation** of the earth's axis, which changes over time. To be accurate, you need to account for
these
effects if not the transformation will be off by kilometers on the surface of the Earth.

Over short time periods (hours to days), this approximation is acceptable for most applications. The error accumulates
slowly.If you need higher precision or longer time spans, use
a [proven library](https://spiceypy.readthedocs.io/en/main/){:target="_blank"}.

## So What's Next?

Now that we understand how to convert between geodetic coordinates and ECEF, we can start working with **local tangent
planes** like **NED** or **ENU**. These local frames are essential for navigation, as they let us describe positions and
orientations relative to a specific location on the Earth’s surface.

## Sources

- [Principles of GNSS, Inertial, and Multisensor Integrated Navigation Systems](https://www.amazon.es/Principles-Inertial-Multisensor-Integrated-Navigation/dp/1608070050)
- [https://www.britannica.com/science/meridian-geography](https://www.britannica.com/science/meridian-geography)
- [Sidereal time](https://en.wikipedia.org/wiki/Sidereal_time)
- [Transform ECI to ECEF question](https://space.stackexchange.com/questions/38807/transform-eci-to-ecef)
- [Polar motion](https://en.wikipedia.org/wiki/Polar_motion)
- [Astronomical nutation](https://en.wikipedia.org/wiki/Astronomical_nutation)
- [Axial precession](https://en.wikipedia.org/wiki/Axial_precession)
- [Coordinate Systems for Modeling](https://es.mathworks.com/help/aeroblks/coordinate-systems-for-modeling.html)
- [Orbital Coordinate Systems](https://celestrak.org/columns/v02n01/)
- [Geographic coordinate conversion](https://en.wikipedia.org/wiki/Geographic_coordinate_conversion)
- [WGS84](https://en.wikipedia.org/wiki/World_Geodetic_System)
- [ECEF](https://en.wikipedia.org/wiki/Earth-centered,_Earth-fixed_coordinate_system)
- [ECI](https://en.wikipedia.org/wiki/Earth-centered_inertial)
- [Trilateration](https://en.wikipedia.org/wiki/Trilateration)
