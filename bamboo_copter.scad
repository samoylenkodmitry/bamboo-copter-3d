<<<<<<< HEAD
// Parametric hand-spun rotor ("bamboo-copter") for PLA on Bambu Lab A1 Mini
// Standard 2/3-blade rotor with washout, optional tip ring, and planform sweep (curved blades)
// Author: ChatGPT — v3 (fix parser error, fuse to hub, add sweep, cleaner ring)
// License: CC BY 4.0

/*
HOW TO USE
1) Edit parameters below. F6 → Export STL.
2) TIP_RING true makes a thin annulus (not a disk).
3) Blades now have planform sweep (curvature) and start near the hub to ensure fusion.

NOTES
- Low-Re flat plate with linear washout (root→tip pitch).
- Chord from solidity: c = sigma * PI * R / N.
- Built by hulling thin sections along span; sections rotate in Z for sweep.
- Units: millimeters.
*/

// -------------------- PARAMETERS --------------------
// Rotor sizing
R_mm = 120;                 // radius [mm] (<=125 for A1 Mini one-piece)
N_blades = 3;               // 2 or 3
sigma   = 0.10;             // solidity target (0.06..0.12 typical)

// Blade plate + washout
thickness_mm = 1.0;         // blade thickness [mm]
aoa_root_deg = 12;          // angle of attack / pitch at root [deg]
aoa_tip_deg  = 5;           // angle of attack / pitch at tip [deg]
washout_curve = 1.5;        // 1.0=linear, >1 = more twist near tip, <1 = more near root
root_chord_scale = 1.00;    // 1.0 = use sigma chord at root
tip_chord_scale  = 0.80;    // taper (0.7..1.0)
sections = 13;              // longitudinal blade sections (>=7 recommended)
root_frac = 0.08;           // aerodynamic root fraction of R (0.05..0.20)
root_frac = 0.08;           // aerodynamic root fraction of R (0.05..0.20)

// Planform sweep (curvature in top view)
sweep_root_deg = 0;         // sweep angle at root [deg]
sweep_tip_deg  = 12;        // sweep angle at tip [deg]

// Hub / shaft
hub_d_mm   = 12;            // hub outer diameter [mm]
hub_h_mm   = 6;             // hub height [mm]
shaft_hole_d_mm = 4.2;      // through-hole for stick/dowel [mm]
fillet_mm  = 1.0;           // small fillet bump at root

// Tip ring (annulus)
TIP_RING = true;            // add ring connecting tips
ring_width_mm = 4.0;        // radial width of ring [mm]
ring_thick_mm = 1.2;        // ring thickness [mm]
ring_clear_mm = 0.6;        // gap from blade tip to ring inner edge

// Tip weight pockets (optional)
TIP_WEIGHTS = false;
tip_pocket_w = 6.0;         // pocket width [mm]
tip_pocket_h = 1.2;         // depth [mm]
tip_pocket_l = 10.0;        // length [mm]

// -------------------- DERIVED --------------------
c_mm = sigma * 3.14159265359 * R_mm / N_blades; // mean chord from solidity
c_root_mm = c_mm * root_chord_scale;
c_tip_mm  = c_mm * tip_chord_scale;
R_aero_mm = R_mm * 0.985;                         // tiny margin for ring
hub_r_mm  = hub_d_mm/2;
R_root_mm = max(hub_r_mm + 0.6, R_mm*root_frac);  // start just beyond hub so it fuses

$fn = 96; $fa = 6; $fs = 0.5;

// -------------------- HELPERS --------------------
function lerp(a,b,t)=a + (b-a)*t;
function chord_at(u) = lerp(c_root_mm, c_tip_mm, u);
function pitch_at(u) = aoa_root_deg + (aoa_tip_deg - aoa_root_deg) * pow(u, washout_curve);
function radius_at(u)= lerp(R_root_mm, R_aero_mm - ring_clear_mm - 0.25, u); // ensure tip meets ring
function sweep_at(u) = lerp(sweep_root_deg, sweep_tip_deg, u);

module plate_2d(w,l){
    offset(r=0.35) square([max(0.4,w-0.7), max(0.4,l-0.7)], center=true);
}

module blade_section(u){
    c = chord_at(u);
    r = radius_at(u);
    p = pitch_at(u);
    s = sweep_at(u);
    // rotate in Z by sweep, then move out along (rotated) Y, then pitch about local x
    rotate([0,0,s])
        translate([0, r, 0])
            rotate([p,0,0])
                linear_extrude(height=thickness_mm)
                    plate_2d(c, thickness_mm);
}


module blade_loft(){
    union(){
        for(i=[0:sections-2]){
            u0 = i/(sections-1);
            u1 = (i+1)/(sections-1);
            hull(){ blade_section(u0); blade_section(u1); }
        }
        // root fusion bump near hub to guarantee manifold union
        hull(){
            translate([0, R_root_mm-1.0, 0]) cylinder(h=thickness_mm, r=fillet_mm);
            translate([0, hub_r_mm+0.2, 0]) cylinder(h=thickness_mm, r=fillet_mm*0.7);
        }
    }
}

module tip_weight_pocket(){
    if(TIP_WEIGHTS){
        u = 0.95; r = radius_at(u);
        rotate([0,0,sweep_at(u)])
            translate([0, r, thickness_mm*0.5])
                rotate([pitch_at(u),0,0])
                    translate([0,0,-tip_pocket_h])
                        cube([tip_pocket_w, tip_pocket_l, tip_pocket_h], center=true);
    }
}

module blade(){
    // Center blade through hub thickness so it truly fuses with hub and ring
    blade_z0 = (hub_h_mm - thickness_mm)/2; // passes through hub solid
    translate([0,0, blade_z0])
        difference(){
            blade_loft();
            tip_weight_pocket();
        }
}

module hub(){
    difference(){
        cylinder(h=hub_h_mm, d=hub_d_mm);
        translate([0,0,-1]) cylinder(h=hub_h_mm+2, d=shaft_hole_d_mm);
    }
}

module tip_ring(){
    if(TIP_RING){
        Rin = R_aero_mm - ring_clear_mm - ring_width_mm;
        Rout = R_aero_mm - ring_clear_mm;
        // Ring built at same Z as blades so they fuse
        ring_z0 = (hub_h_mm - ring_thick_mm)/2;
        translate([0,0, ring_z0])
            linear_extrude(height=ring_thick_mm)
                difference(){
                    circle(r=Rout);
                    circle(r=max(0.2, Rin));
                }
    }
}

module rotor(){
    union(){
        hub();
        for(k=[0:N_blades-1])
            rotate([0,0, k*360/N_blades]) blade();
        tip_ring();
    }
}

// -------------------- BUILD --------------------
=======
// Bamboo-copter — parametric rotor for 3D print
// v14: Z=0 bottoms, pitch about Y (AoA), sweep, *robust* blade↔ring tabs,
//      square hub hole, flat tangent stick.
// License: CC BY 4.0

/********* PRINT *********
- Print flat, no supports. PLA 0.2 mm, 3 walls, 3 top/bottom, 0–15% infill.
- For Bambu A1 Mini one-piece, keep R_mm ≤ 120–125.
**************************/

// ---------------- PARAMETERS ----------------
R_mm = 120;                 // rotor radius [mm]
N_blades = 3;               // 2..5 blades

// Spin direction viewed from +Z (top): true = CCW, false = CW
spin_ccw   = true;
pitch_sign = spin_ccw ? 1 : -1;

// Aerodynamic sizing
sigma            = 0.10;    // 0.06..0.12 typical
root_chord_scale = 1.00;
tip_chord_scale  = 0.80;

// Blade twist (AoA)
aoa_root_deg  = 16;
aoa_tip_deg   = 6;
washout_curve = 1.6;        // 1=linear; >1 twist concentrated near tip

// Geometry
thickness_mm = 1.0;
sections     = 61;          // 61–81 very smooth
root_frac    = 0.08;
span_overlap = 1.35;

// Smooth loft option (keeps thickness)
SMOOTH_LOFT = true;
loft_eps    = 0.02;

// Planform sweep (curvature in top view)
sweep_root_deg = 0;
sweep_tip_deg  = 12;

// Hub / shaft (bottom at Z=0)
hub_d_mm          = 12;
hub_h_mm          = 6;
shaft_hole_shape  = "square";  // "square" or "round"
shaft_hole_d_mm   = 4.2;       // used if round
shaft_square_mm   = 5.0;       // target stick size
hole_clearance_mm = 0.25;      // added to hole/square
square_corner_r   = 0.6;       // fillet for square corners
fillet_mm         = 1.0;       // tiny root fillet bump

// Tip ring (bottom at Z=0)
TIP_RING      = true;
ring_width_mm = 4.0;
ring_thick_mm = 1.6;           // a bit thicker so it grabs the tabs well
ring_clear_mm = 0.6;

// Blade→ring connection (oversized to *guarantee* fusion)
CONNECT_TO_RING      = true;
tip_overlap_mm       = 1.6;    // blade intrudes past inner ring
tab_width_mm         = 4.0;    // tangential width of tab
tab_radial_depth_mm  = 3.5;    // radial depth across ring inner wall
tab_extra_height_mm  = 3.0;    // added Z height so tab always reaches blade

// Stick (flat, tangent to ring)
SHOW_STICK      = true;
stick_square_mm = 5.0;
stick_len_mm    = 180;
stick_round_r   = 0.8;
stick_angle_deg = 0;           // 0, 90, 180, -90 … around the ring

$fn = 96; $fa = 6; $fs = 0.5;

// ---------------- DERIVED ----------------
c_mm      = sigma * PI * R_mm / N_blades;
c_root_mm = c_mm * root_chord_scale;
c_tip_mm  = c_mm * tip_chord_scale;
hub_r_mm  = hub_d_mm/2;
R_aero_mm = R_mm * 0.985;
R_root_mm = max(hub_r_mm + 0.6, R_mm*root_frac);
Rin_ring  = R_aero_mm - ring_clear_mm - ring_width_mm;
Rout_ring = R_aero_mm - ring_clear_mm;

// ---------------- HELPERS ----------------
function lerp(a,b,t)= a + (b-a)*t;
function chord_at(u)= lerp(c_root_mm, c_tip_mm, u);
function pitch_at(u)= aoa_root_deg + (aoa_tip_deg - aoa_root_deg)*pow(u, washout_curve);
function sweep_at(u)= lerp(sweep_root_deg, sweep_tip_deg, u);
function tip_target_radius() = CONNECT_TO_RING ? (Rin_ring + tip_overlap_mm)
                                               : (Rout_ring - 0.25);
function radius_at(u) = lerp(R_root_mm, tip_target_radius(), u);

// ---------------- SLICES (from Z=0 up) ----------------
// NOTE: We do *not* try to force every vertex to Z=0. Instead, we build from Z=0..thickness,
// and rely on the big tabs to ensure overlap with the ring.
module plate_at(u, h){
  c  = chord_at(u);
  r  = radius_at(u);
  p  = pitch_at(u);
  s  = sweep_at(u);
  dR = (R_aero_mm - R_root_mm)/(sections-1);

  rotate([0, pitch_sign*p, 0])         // AoA about Y
    rotate([0,0,s])                    // planform sweep
      translate([0, r, 0])             // out to radius
        linear_extrude(height=h, center=false)  // base at Z=0
          offset(r=0.25)
            square([max(0.6, c-0.5), dR*span_overlap], center=true);
}

// ---------------- BLADE ----------------
module blade_body_fast(){
  union(){
    for(i=[0:sections-1]) plate_at(i/(sections-1), thickness_mm);
    // tiny root filler up from Z=0
    hull(){
      translate([0, hub_r_mm+0.4, 0]) cylinder(h=thickness_mm, r=fillet_mm*0.8, center=false);
      translate([0, R_root_mm,   0]) cylinder(h=thickness_mm, r=fillet_mm*0.8, center=false);
    }
  }
}

module blade_body_smooth(){
  t = thickness_mm;
  union(){
    // top skin
    for(i=[0:sections-2]){
      u0=i/(sections-1); u1=(i+1)/(sections-1);
      hull(){ translate([0,0,t-loft_eps]) plate_at(u0, loft_eps); plate_at(u1, loft_eps); }
    }
    // bottom skin
    for(i=[0:sections-2]){
      u0=i/(sections-1); u1=(i+1)/(sections-1);
      hull(){ plate_at(u0, loft_eps); plate_at(u1, loft_eps); }
    }
    // close ends
    hull(){ plate_at(0, t);    plate_at(0.001, t); }
    hull(){ plate_at(1.0, t);  plate_at(0.999, t); }
    // root filler
    hull(){
      translate([0, hub_r_mm+0.4, 0]) cylinder(h=t, r=fillet_mm*0.8, center=false);
      translate([0, R_root_mm,   0]) cylinder(h=t, r=fillet_mm*0.8, center=false);
    }
  }
}

module blade_body(){ if (SMOOTH_LOFT) blade_body_smooth(); else blade_body_fast(); }
module blade(){ blade_body(); }

// ---------------- HUB / RING (bottom at Z=0) ----------------
module hub(){
  module hole2d(){
    if (shaft_hole_shape=="square")
      offset(r=square_corner_r)
        square([shaft_square_mm+hole_clearance_mm,
                shaft_square_mm+hole_clearance_mm], center=true);
    else circle(d=shaft_hole_d_mm+hole_clearance_mm);
  }
  difference(){
    cylinder(h=hub_h_mm, d=hub_d_mm, center=false);
    translate([0,0,-0.1]) linear_extrude(height=hub_h_mm+0.2, center=false) hole2d();
  }
}

module tip_ring(){
  if (TIP_RING){
    linear_extrude(height=ring_thick_mm, center=false)
      difference(){ circle(r=Rout_ring); circle(r=max(0.2, Rin_ring)); }
  }
}

// ---------------- RING CONNECTOR TABS (oversized, bottom at Z=0) ----------------
module ring_connectors(){
  if (TIP_RING && CONNECT_TO_RING){
    // make tabs tall & deep enough to hit both ring and blade regardless of pitch
    tab_h = ring_thick_mm + thickness_mm + tab_extra_height_mm;
    r_mid = Rin_ring + tab_radial_depth_mm/2;
    a_tip = sweep_at(1.0);                // blade tip azimuth (include sweep)

    for (k=[0:N_blades-1]){
      rotate([0,0, k*360/N_blades + a_tip])
        translate([0, r_mid, 0])
          cube([tab_width_mm, tab_radial_depth_mm, tab_h], center=false);
    }
  }
}

// ---------------- STICK (flat & tangent; bottom at Z=0) ----------------
module stick(){
  if (SHOW_STICK){
    s = stick_square_mm; r = stick_round_r; L = stick_len_mm; a = stick_angle_deg;
    rotate([0,0,a])
      translate([R_mm + 10 + s/2, 0, 0])
        rotate([0,0,90])
          linear_extrude(height=s, center=false)
            offset(r=r) square([L, s], center=true);
  }
}

// ---------------- ASSEMBLY ----------------
module rotor(){
  union(){
    hub();
    for (k=[0:N_blades-1]) rotate([0,0, k*360/N_blades]) blade();
    tip_ring();
    ring_connectors();
  }
}

// ---------------- BUILD ----------------
stick();
>>>>>>> ecd639c (Initial commit: Complete bamboo copter design collection)
rotor();
