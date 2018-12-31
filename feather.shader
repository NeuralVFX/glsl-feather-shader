


Shader "Feather GEO Shader" { // defines the name of the shader 

	Properties{
	   _MainTex("Texture Image", 2D) = "white" {}
	   _Scale("Scale", Float) = 10
	   _Rotate("Rotate", Float) = 90
	   _Density("Density", Float) = 100
	}

		SubShader{ // Unity chooses the subshader that fits the GPU best
		    Pass {
		    Cull Off // some shaders require multiple passes
		    GLSLPROGRAM // here begins the part in Unity's GLSL\
		    #include "UnityCG.glslinc" 

			uniform mat4 unity_CameraProjection;
			uniform vec4 unity_Scale; 
			uniform float _Scale;
			uniform float _Rotate;
			uniform float _Density;
			uniform sampler2D _MainTex;

			mat3 get_face_matrix(vec4 pos_0,vec4 pos_1,vec4 pos_2, vec2 uv_0,vec2 uv_1, vec2 uv_2, vec3 n){
				// make position basis vectors
				vec3 p_dx = pos_1.xyz- pos_0.xyz;
				vec3 p_dy = pos_2.xyz- pos_0.xyz;

				// make uv basis vactors
				vec2 tc_dx = uv_1-uv_0;
				vec2 tc_dy = uv_2-uv_0;
    
				// basis matrices
				mat3x3 poly_basis = mat3x3(p_dx,p_dy,n);
				mat2x2 uv_basis = mat2x2(tc_dx,tc_dy);
    
				// convert X
				mat2x2 inv_uv = inverse(uv_basis);
				vec2 def_space = inv_uv*vec2(1.0,0.);
				vec3 def_space_3 = vec3(def_space,0.);
				vec3 t = normalize(poly_basis*def_space_3);
    
				// convert Z
				vec2 def_space_y = inv_uv*vec2(0,1.);
				vec3 def_space_3_y = vec3(def_space_y,0.);
				vec3 x = normalize(poly_basis*def_space_3_y);
    
				// make clean Y
				n = cross(x,t);

				mat3 tbn = mat3(t, n, x);
    
				return tbn;
			}

			float tri_area(vec4 a,vec4 b,vec4 c){
				// caculate triangle area
				float ab = distance(a,b);
				float ac = distance(a,c);
				float cb = distance(c,b);
				float p = (ab+ ac+ cb)/2.;
				float area = sqrt(p*(p -ab)*( p -ac)*(p -cb));
				return area;
			}

			vec4 avg_from_bary_4(vec4 a,vec4 b,vec4 c,vec3 bary){
				// average a 3d vector based on barycentric coords
				vec4 avg = ((a*bary.x)+(b*bary.y)+(c*bary.z));
				return avg;
			}

			vec2 avg_from_bary_2(vec2 a,vec2 b,vec2 c,vec3 bary){
				// average a 2d vector using barycentrix coords
				vec2 avg = ((a*bary.x)+(b*bary.y)+(c*bary.z));
				return avg;
			}

			float rand(vec2 co){
				// get random number
				return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453)*3.1;
			}

			vec3 rand_bary_coord(vec2 co){
				// find random barycentric coords
				float val_a = .2;
				float val_b = 1.2;

				vec2 co_a = co;
    
				for (float i= 0;i < 100. || (val_a+val_b) > 1.;i++ ){
					val_a = rand(co+i);
					val_b = rand(vec2(co_a.x,val_a));
					co_a += vec2(val_a,val_b);
				}
				return vec3(val_a,val_b,1.-(val_a+val_b));  
			}

			mat3 rotationMatrix(vec3 axis, float angle){
				// build rotation matrix for feather rotation
				axis = normalize(axis);
				float s = sin(angle);
				float c = cos(angle);
				float oc = 1.0 - c;

				return mat3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,
							oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,
							oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c);
			}

			#ifdef VERTEX // here begins the vertex shader

				out VertexData
				{
					vec4 v_position;
					vec3 v_normal;
					vec2 v_texcoord;
					vec3 light_dir;
				} outData;

				void main(void)
				{

					gl_Position = gl_Vertex;


					outData.v_position =  gl_Vertex;
					outData.v_normal = normalize(vec4(-gl_Normal,0)).xyz;
					// set light rotation to object space
					outData.light_dir = (normalize(unity_WorldToObject*_WorldSpaceLightPos0).xyz);
					outData.v_texcoord = gl_MultiTexCoord0.xy;
				}

			#endif // here ends the definition of the vertex shader
			
			#ifdef GEOMETRY
				in VertexData
				{
					vec4 v_position;
					vec3 v_normal;
					vec2 v_texcoord;
					vec3 light_dir;
				} inData[];

				out VertexData
				{
					vec4 v_position;
					vec3 v_normal;
					vec2 v_texcoord;
					vec3 light_dir;
				} outData;

				layout(triangles) in;
				layout(triangle_strip, max_vertices = 256) out;
				void main()
				{
					// set light dir
					outData.light_dir = normalize(gl_NormalMatrix * inData[0].light_dir);

					// create original surface polygons
					outData.v_texcoord = inData[0].v_texcoord;
					outData.v_normal = normalize(gl_NormalMatrix * inData[0].v_normal);
					gl_Position = gl_ModelViewProjectionMatrix * gl_in[0].gl_Position;
					EmitVertex();

					outData.v_texcoord = inData[1].v_texcoord;
					outData.v_normal = normalize(gl_NormalMatrix * inData[1].v_normal);
					gl_Position = gl_ModelViewProjectionMatrix * gl_in[1].gl_Position;
					EmitVertex();

					outData.v_texcoord = inData[2].v_texcoord;
					outData.v_normal = normalize(gl_NormalMatrix * inData[2].v_normal);
					gl_Position = gl_ModelViewProjectionMatrix * gl_in[2].gl_Position;
					EmitVertex();

					EndPrimitive();

					// build our feather matrix
					mat3 rot_mat = rotationMatrix(vec3(1, 0, 0), _Rotate / 3.14);
					vec3 n = normalize(inData[0].v_normal + inData[1].v_normal + inData[2].v_normal);
					mat3 face_mat = get_face_matrix(gl_in[0].gl_Position, gl_in[1].gl_Position, gl_in[2].gl_Position, inData[0].v_texcoord, inData[1].v_texcoord, inData[2].v_texcoord, n);
					vec4 pos = gl_in[0].gl_Position;
					face_mat = face_mat * rot_mat;
					// get feather area
					float area = tri_area(gl_in[0].gl_Position, gl_in[1].gl_Position, gl_in[2].gl_Position);

					vec2 co = vec2(inData[0].v_texcoord.x, inData[1].v_texcoord.y);
					vec3 bary_coord;

					// create feathers
					for (float i = 1.; i < area*_Density; i++){
						// select barycentric coordinate
						bary_coord = rand_bary_coord(co);
						co += bary_coord.xy;
						// average UV coord and positions based on bary coordinate
						vec4 feath_pos = avg_from_bary_4(gl_in[0].gl_Position, gl_in[1].gl_Position, gl_in[2].gl_Position, bary_coord);
						vec2 uv = avg_from_bary_2(inData[0].v_texcoord, inData[1].v_texcoord, inData[2].v_texcoord, bary_coord);

						// buid feather
						vec3 norm = normalize(gl_NormalMatrix*( face_mat * vec3(0, -1, 0)));
						outData.v_texcoord = uv;
						outData.v_normal = norm;
						gl_Position = gl_ModelViewProjectionMatrix *(vec4(face_mat*(vec3(-0.00214230008423,0, 0)*_Scale), 0) + feath_pos);
						EmitVertex();
						gl_Position = gl_ModelViewProjectionMatrix * (vec4(face_mat*(vec3(-0.0638984024525,0, .1)*_Scale), 0) + feath_pos);
						EmitVertex();
						gl_Position = gl_ModelViewProjectionMatrix * (vec4(face_mat* (vec3(0.0638984024525,0, 0.1)*_Scale), 0) + feath_pos);
						EmitVertex();
						gl_Position = gl_ModelViewProjectionMatrix * (vec4(face_mat*(vec3(-0.0964446008205,0, 0.2)*_Scale), 0) + feath_pos);
						EmitVertex();
						gl_Position = gl_ModelViewProjectionMatrix * (vec4(face_mat*(vec3(0.0964446008205,0, 0.2)*_Scale), 0) + feath_pos);
						EmitVertex();
						gl_Position = gl_ModelViewProjectionMatrix * (vec4(face_mat* (vec3(-0.0964446008205,0, 0.4)*_Scale), 0) + feath_pos);
						EmitVertex();
						gl_Position = gl_ModelViewProjectionMatrix * (vec4(face_mat*(vec3(0.0964446008205,0, 0.4)*_Scale), 0) + feath_pos);
						EmitVertex();
						gl_Position = gl_ModelViewProjectionMatrix * (vec4(face_mat*(vec3(-0.0638984024525,0, .5)*_Scale), 0) + feath_pos);
						EmitVertex();
						gl_Position = gl_ModelViewProjectionMatrix * (vec4(face_mat*(vec3(0.0638984024525,0, .5)*_Scale), 0) + feath_pos);
						EmitVertex();
						gl_Position = gl_ModelViewProjectionMatrix * (vec4(face_mat* (vec3(-0.00214230008423,0, .6)*_Scale), 0) + feath_pos);
						EmitVertex();
						EndPrimitive();

					}
				}
			#endif

			#ifdef FRAGMENT // here begins the fragment shader

			in VertexData
			{
				vec4 v_position;
				vec3 v_normal;
				vec2 v_texcoord;
				vec3 light_dir;
			} inData;

			void main() // all fragment shaders define a main() function
			{
				// simple lambert lighting
				float lgt = clamp(dot(inData.v_normal, -inData.light_dir),0.,1.);
				lgt = lgt * .5 + .5;
				vec4 tex = texture2D(_MainTex, inData.v_texcoord);

				gl_FragColor = tex*lgt;
		  
			}

			#endif // here ends the definition of the fragment shader

	        	ENDGLSL // here ends the part in GLSL 
        	}
	}
}
