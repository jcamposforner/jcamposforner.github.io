---
title: "Navigation Systems: Body Rigid Transformations and Heading Estimation from Bearing Measurements"
description: ""
categories: [ Navigation, Coordinate Transformations, Coordinate Frames, Target Tracking, Sensor Fusion ]
tags: [ Navigation, Coordinate Systems, Reference Frames, Earth Coordinates, Earth, NED, Orientation, Position, Geospatial, Bearing Measurements, Heading Estimation ]
hidden: false
math: true
read_complexity: 2.0
---

Why we need to transform this coordinates

Talk about how sensors provide measurements based on their own frame.

![enu-observation](/assets/img/navigation/coordinates-transformations/enu-observation.gif)

How radar provides bearing measurements relative to its own body frame. Explain a bit about spherical coordinates again,
link to previous post.

![radar](/assets/img/navigation/coordinates-transformations/radar.gif)

Explain a bit about ENU origins matters to get correct results.

Present the problem about a radar seeing a target in dt, and we want to estimate his position. Also mention that the
target may be moving and also how to estimate heading from multiple measurements.

Visualize a pipeline of coordinate transformations.

Explain body rigid transformations.

Code example

After the first problem present the next problem about the same moving target reporting to the ENU base station, and
observation of a moving car. So we need to take the estimated heading from the first object and get the same DT
observation to calculate the second object position / heading ( Course Over Ground ) because we don't know where the
first object is pointing the only we know is the direction.

Line of Sight (LOS)

The vector to get from the observer coordinate to the target coordinate.

Code example

Landmark navigation, convergence algorithm to estimate position based on multiple observations from known landmarks.

![landmark](/assets/img/navigation/coordinates-transformations/sagrada-familia.png)

![estimated-distance-landmark](/assets/img/navigation/coordinates-transformations/estimated-distance.png)

Explain what we can do with these estimations, like sensor fusion, tracking, know the distances from multiple targets,
calculate spherical coordinates to lock on targets, how to know if we're approaching or moving away from them, how to
know if it is the same target.

Explain that these estimations are useful for sensor fusion and tracking, but they can have errors due to noise and other
factors. Introduce the idea of Kalman Filters.