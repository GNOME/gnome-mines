/** OpenAL bindings for Vala
 *
 * Copyright 2020-2021 Anton "Vuvk" Shcherbatykh <vuvk69@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "al.h")]
namespace AL
{
	// 8-bit boolean
	[BooleanType]
	[CCode (cname = "ALboolean", has_type_id = false)]
	public struct Boolean : int8 {}

	// character
	[CCode (cname = "ALchar", has_type_id = false)]
	public struct Char : char {}

	// signed 8-bit 2's complement integer
	[CCode (cname = "ALbyte", has_type_id = false)]
	public struct Byte : int8 {}

	// unsigned 8-bit integer
	[CCode (cname = "ALubyte", has_type_id = false)]
	public struct Ubyte : uint8 {}

	// signed 16-bit 2's complement integer
	[CCode (cname = "ALshort", has_type_id = false)]
	public struct Short : int16 {}

	// unsigned 16-bit integer
	[CCode (cname = "ALushort", has_type_id = false)]
	public struct Ushort : uint16 {}

	// signed 32-bit 2's complement integer
	[CCode (cname = "ALint", has_type_id = false)]
	public struct Int : int32 {}

	// unsigned 32-bit integer
	[CCode (cname = "ALuint", has_type_id = false)]
	public struct Uint : uint32 {}

	// non-negative 32-bit binary integer size
	[CCode (cname = "ALsizei", has_type_id = false)]
	public struct Sizei : int32 {}

	// enumerated 32-bit value
	[CCode (cname = "ALenum", has_type_id = false)]
	public struct Enum : int32 {}

	// 32-bit IEEE754 floating-point
	[CCode (cname = "ALfloat", has_type_id = false)]
	public struct Float : float {}

	// 64-bit IEEE754 floating-point
	[CCode (cname = "ALdouble", has_type_id = false)]
	public struct Double : double {}

	// void type (for opaque pointers only)
	[CCode (cname = "ALvoid", has_type_id = false)]
	public struct Void {}

	/** "no distance model" or "no buffer" */
	[CCode (cname = "AL_NONE")]
	public const Enum NONE;

	/** Boolean False. */
	[CCode (cname = "AL_FALSE")]
	public const Enum FALSE;

	/** Boolean True. */
	[CCode (cname = "AL_TRUE")]
	public const Enum TRUE;

	/**
	* Relative source.
	* Type:	ALboolean
	* Range: [AL_TRUE, AL_FALSE]
	* Default: AL_FALSE
	*
	* Specifies if the Source has relative coordinates.
	*/
	[CCode (cname = "AL_SOURCE_RELATIVE")]
	public const Enum SOURCE_RELATIVE;

	/**
	* Inner cone angle, in degrees.
	* Type:	ALint, ALfloat
	* Range: [0 - 360]
	* Default: 360
	*
	* The angle covered by the inner cone, where the source will not attenuate.
	*/
	[CCode (cname = "AL_CONE_INNER_ANGLE")]
	public const Enum CONE_INNER_ANGLE;

	/**
	* Outer cone angle, in degrees.
	* Range: [0 - 360]
	* Default: 360
	*
	* The angle covered by the outer cone, where the source will be fully
	* attenuated.
	*/
	[CCode (cname = "AL_CONE_OUTER_ANGLE")]
	public const Enum CONE_OUTER_ANGLE;

	/**
	* Source pitch.
	* Type:	ALfloat
	* Range: [0.5 - 2.0]
	* Default: 1.0
	*
	* A multiplier for the frequency (sample rate) of the source's buffer.
	*/
	[CCode (cname = "AL_PITCH")]
	public const Enum PITCH;

	/**
	* Source or listener position.
	* Type:	ALfloat[3] , ALint[3]
	* Default: {0, 0, 0}
	*
	* The source or listener location in three dimensional space.
	*
	* OpenAL, like OpenGL, uses a right handed coordinate system, where in a
	* frontal default view X (thumb) points right, Y points up (index finger), and
	* Z points towards the viewer/camera (middle finger).
	*
	* To switch from a left handed coordinate system, flip the sign on the Z
	* coordinate.
	*/
	[CCode (cname = "AL_POSITION")]
	public const Enum POSITION;

	/**
	* Source direction.
	* Type:	ALfloat[3] , ALint[3]
	* Default: {0, 0, 0}
	*
	* Specifies the current direction in local space.
	* A zero-length vector specifies an omni-directional source (cone is ignored).
	*/
	[CCode (cname = "AL_DIRECTION")]
	public const Enum DIRECTION;

	/**
	* Source or listener velocity.
	* Type:	ALfloat[3] , ALint[3]
	* Default: {0, 0, 0}
	*
	* Specifies the current velocity in local space.
	*/
	[CCode (cname = "AL_VELOCITY")]
	public const Enum VELOCITY;

	/**
	* Source looping.
	* Type:	ALboolean
	* Range: [AL_TRUE, AL_FALSE]
	* Default: AL_FALSE
	*
	* Specifies whether source is looping.
	*/
	[CCode (cname = "AL_LOOPING")]
	public const Enum LOOPING;

	/**
	* Source buffer.
	* Type: ALuint
	* Range: any valid Buffer.
	*
	* Specifies the buffer to provide sound samples.
	*/
	[CCode (cname = "AL_BUFFER")]
	public const Enum BUFFER;

	/**
	* Source or listener gain.
	* Type: ALfloat
	* Range: [0.0 - ]
	*
	* A value of 1.0 means unattenuated. Each division by 2 equals an attenuation
	* of about -6dB. Each multiplicaton by 2 equals an amplification of about
	* +6dB.
	*
	* A value of 0.0 is meaningless with respect to a logarithmic scale; it is
	* silent.
	*/
	[CCode (cname = "AL_GAIN")]
	public const Enum GAIN;

	/**
	* Minimum source gain.
	* Type: ALfloat
	* Range: [0.0 - 1.0]
	*
	* The minimum gain allowed for a source, after distance and cone attenation is
	* applied (if applicable).
	*/
	[CCode (cname = "AL_MIN_GAIN")]
	public const Enum MIN_GAIN;

	/**
	* Maximum source gain.
	* Type: ALfloat
	* Range: [0.0 - 1.0]
	*
	* The maximum gain allowed for a source, after distance and cone attenation is
	* applied (if applicable).
	*/
	[CCode (cname = "AL_MAX_GAIN")]
	public const Enum MAX_GAIN;

	/**
	* Listener orientation.
	* Type: ALfloat[6]
	* Default: {0.0, 0.0, -1.0, 0.0, 1.0, 0.0}
	*
	* Effectively two three dimensional vectors. The first vector is the front (or
	* "at") and the second is the top (or "up").
	*
	* Both vectors are in local space.
	*/
	[CCode (cname = "AL_ORIENTATION")]
	public const Enum ORIENTATION;

	/**
	* Source state (query only).
	* Type: ALint
	* Range: [AL_INITIAL, AL_PLAYING, AL_PAUSED, AL_STOPPED]
	*/
	[CCode (cname = "AL_SOURCE_STATE")]
	public const Enum SOURCE_STATE;

	/** Source state value. */
	[CCode (cname = "ALint", cprefix = "AL_", has_type_id = false)]
	public enum SourceState
	{
		INITIAL,
		PLAYING,
		PAUSED,
		STOPPED
	}

	/**
	* Source Buffer Queue size (query only).
	* Type: ALint
	*
	* The number of buffers queued using alSourceQueueBuffers, minus the buffers
	* removed with alSourceUnqueueBuffers.
	*/
	[CCode (cname = "AL_BUFFERS_QUEUED")]
	public const Enum BUFFERS_QUEUED;

	/**
	* Source Buffer Queue processed count (query only).
	* Type: ALint
	*
	* The number of queued buffers that have been fully processed, and can be
	* removed with alSourceUnqueueBuffers.
	*
	* Looping sources will never fully process buffers because they will be set to
	* play again for when the source loops.
	*/
	[CCode (cname = "AL_BUFFERS_PROCESSED")]
	public const Enum BUFFERS_PROCESSED;

	/**
	* Source reference distance.
	* Type:	ALfloat
	* Range: [0.0 - ]
	* Default: 1.0
	*
	* The distance in units that no attenuation occurs.
	*
	* At 0.0, no distance attenuation ever occurs on non-linear attenuation models.
	*/
	[CCode (cname = "AL_REFERENCE_DISTANCE")]
	public const Enum REFERENCE_DISTANCE;

	/**
	* Source rolloff factor.
	* Type:	ALfloat
	* Range: [0.0 - ]
	* Default: 1.0
	*
	* Multiplier to exaggerate or diminish distance attenuation.
	*
	* At 0.0, no distance attenuation ever occurs.
	*/
	[CCode (cname = "AL_ROLLOFF_FACTOR")]
	public const Enum ROLLOFF_FACTOR;

	/**
	* Outer cone gain.
	* Type:	ALfloat
	* Range: [0.0 - 1.0]
	* Default: 0.0
	*
	* The gain attenuation applied when the listener is outside of the source's
	* outer cone.
	*/
	[CCode (cname = "AL_CONE_OUTER_GAIN")]
	public const Enum CONE_OUTER_GAIN;

	/**
	* Source maximum distance.
	* Type:	ALfloat
	* Range: [0.0 - ]
	* Default: +inf
	*
	* The distance above which the source is not attenuated any further with a
	* clamped distance model, or where attenuation reaches 0.0 gain for linear
	* distance models with a default rolloff factor.
	*/
	[CCode (cname = "AL_MAX_DISTANCE")]
	public const Enum MAX_DISTANCE;

	[CCode (cname = "ALenum", cprefix = "AL_", has_type_id = false)]
	public enum SourceBufferPosition
	{
		/** Source buffer position, in seconds */
		SEC_OFFSET,
		/** Source buffer position, in sample frames */
		SAMPLE_OFFSET,
		/** Source buffer position, in bytes */
		BYTE_OFFSET
	}

	/**
	* Source type (query only).
	* Type: ALint
	* Range: [AL_STATIC, AL_STREAMING, AL_UNDETERMINED]
	*
	* A Source is Static if a Buffer has been attached using AL_BUFFER.
	*
	* A Source is Streaming if one or more Buffers have been attached using
	* alSourceQueueBuffers.
	*
	* A Source is Undetermined when it has the NULL buffer attached using
	* AL_BUFFER.
	*/
	[CCode (cname = "AL_SOURCE_TYPE")]
	public const Enum SOURCE_TYPE;

	/** Source type value. */
	[CCode (cname = "ALint", cprefix = "AL_", has_type_id = false)]
	public enum SourceType
	{
		STATIC,
		STREAMING,
		UNDETERMINED
	}

	/** Buffer format specifier. */
	[CCode (cname = "ALenum", cprefix = "AL_FORMAT_", has_type_id = false)]
	public enum BufferFormat
	{
		MONO8,
		MONO16,
		STEREO8,
		STEREO16
	}

	/** Buffer frequency (query only). */
	[CCode (cname = "AL_FREQUENCY")]
	public const Enum FREQUENCY;
	/** Buffer bits per sample (query only). */
	[CCode (cname = "AL_BITS")]
	public const Enum BITS;
	/** Buffer channel count (query only). */
	[CCode (cname = "AL_CHANNELS")]
	public const Enum CHANNELS;
	/** Buffer data size (query only). */
	[CCode (cname = "AL_SIZE")]
	public const Enum SIZE;

	/**
	* Buffer state.
	*
	* Not for public use.
	*/
	[CCode (cname = "ALenum", cprefix = "AL_", has_type_id = false)]
	public enum BufferState
	{
		UNUSED,
		PENDING,
		PROCESSED
	}

	[CCode (cname = "ALenum", cprefix = "AL_", has_type_id = false)]
	public enum Error
	{
		/** No error. */
		NO_ERROR,
		/** Invalid name paramater passed to AL call. */
		INVALID_NAME,
		/** Invalid enum parameter passed to AL call. */
		INVALID_ENUM,
		/** Invalid value parameter passed to AL call. */
		INVALID_VALUE,
		/** Illegal AL call. */
		INVALID_OPERATION
		/** Not enough memory. */,
		OUT_OF_MEMORY
	}

	/** Context string: Vendor ID. */
	[CCode (cname = "AL_VENDOR")]
	public const Enum VENDOR;
	/** Context string: Version. */
	[CCode (cname = "AL_VERSION")]
	public const Enum VERSION;
	/** Context string: Renderer ID. */
	[CCode (cname = "AL_RENDERER")]
	public const Enum RENDERER;
	/** Context string: Space-separated extension list. */
	[CCode (cname = "AL_EXTENSIONS")]
	public const Enum EXTENSIONS;

	/**
	* Doppler scale.
	* Type:	ALfloat
	* Range: [0.0 - ]
	* Default: 1.0
	*
	* Scale for source and listener velocities.
	*/
	[CCode (cname = "AL_DOPPLER_FACTOR")]
	public const Enum DOPPLER_FACTOR;

	/**
	* Doppler velocity (deprecated).
	*
	* A multiplier applied to the Speed of Sound.
	*/
	[CCode (cname = "AL_DOPPLER_VELOCITY")]
	public const Enum DOPPLER_VELOCITY;

	/**
	* Speed of Sound, in units per second.
	* Type:	ALfloat
	* Range: [0.0001 - ]
	* Default: 343.3
	*
	* The speed at which sound waves are assumed to travel, when calculating the
	* doppler effect.
	*/
	[CCode (cname = "AL_SPEED_OF_SOUND")]
	public const Enum SPEED_OF_SOUND;

	/**
	* Distance attenuation model.
	* Type:	ALint
	* Range: [AL_NONE, AL_INVERSE_DISTANCE, AL_INVERSE_DISTANCE_CLAMPED,
	*		 AL_LINEAR_DISTANCE, AL_LINEAR_DISTANCE_CLAMPED,
	*		 AL_EXPONENT_DISTANCE, AL_EXPONENT_DISTANCE_CLAMPED]
	* Default: AL_INVERSE_DISTANCE_CLAMPED
	*
	* The model by which sources attenuate with distance.
	*
	* None	 - No distance attenuation.
	* Inverse - Doubling the distance halves the source gain.
	* Linear - Linear gain scaling between the reference and max distances.
	* Exponent - Exponential gain dropoff.
	*
	* Clamped variations work like the non-clamped counterparts, except the
	* distance calculated is clamped between the reference and max distances.
	*/
	[CCode (cname = "AL_DISTANCE_MODEL")]
	public const Enum DISTANCE_MODEL;

	/** Distance model value. */
	[CCode (cname = "ALint", cprefix = "AL_", has_type_id = false)]
	public enum DistanceModel
	{
		INVERSE_DISTANCE,
		INVERSE_DISTANCE_CLAMPED,
		LINEAR_DISTANCE,
		LINEAR_DISTANCE_CLAMPED,
		EXPONENT_DISTANCE,
		EXPONENT_DISTANCE_CLAMPED
	}

	[CCode (cname = "alDopplerFactor")]
	public void doppler_factor (Float value);
	[CCode (cname = "alDopplerVelocity")]
	public void doppler_velocity (Float value);
	[CCode (cname = "alSpeedOfSound")]
	public void speed_of_sound (Float value);
	[CCode (cname = "alDistanceModel")]
	public void distance_model (DistanceModel distanceModel);

	/** Renderer State management. */
	[CCode (cname = "alEnable")]
	public void enable (Enum capability);
	[CCode (cname = "alDisable")]
	public void disable (Enum capability);
	[CCode (cname = "alIsEnabled")]
	public bool is_enabled (Enum capability);

	/** State retrieval. */
	[CCode (cname = "alGetString")]
	public unowned string? get_string (Enum param);
	[CCode (cname = "alGetBooleanv")]
	public void get_booleanv (Enum param, [CCode (array_length = false)] Boolean[] values);
	[CCode (cname = "alGetIntegerv")]
	public void get_integerv (Enum param, [CCode (array_length = false)] Int[] values);
	[CCode (cname = "alGetFloatv")]
	public void get_floatv (Enum param, [CCode (array_length = false)] Float[] values);
	[CCode (cname = "alGetDoublev")]
	public void get_doublev (Enum param, [CCode (array_length = false)] Double[] values);
	[CCode (cname = "alGetBoolean")]
	public bool get_boolean (Enum param);
	[CCode (cname = "alGetInteger")]
	public Int get_integer (Enum param);
	[CCode (cname = "alGetFloat")]
	public Float get_float (Enum param);
	[CCode (cname = "alGetDouble")]
	public Double get_double (Enum param);

	/**
	* Error retrieval.
	*
	* Obtain the first error generated in the AL context since the last check.
	*/
	[CCode (cname = "alGetError")]
	public Error get_error ();

	/**
	* Extension support.
	*
	* Query for the presence of an extension, and obtain any appropriate function
	* pointers and enum values.
	*/
	[CCode (cname = "alIsExtensionPresent")]
	public bool is_extension_present (string extname);
	[CCode (cname = "alGetProcAddress")]
	public void* get_proc_address (string fname);
	[CCode (cname = "alGetEnumValue")]
	public Enum get_enum_value (string ename);

	namespace Listener {
		/** Set Listener parameters */
		[CCode (cname = "alListenerf")]
		public static void set_paramf (Enum param, Float value);
		[CCode (cname = "alListener3f")]
		public static void set_param3f (Enum param, Float value1, Float value2, Float value3);
		[CCode (cname = "alListenerfv")]
		public static void set_paramfv (Enum param, [CCode (array_length = false)] Float[] values);
		[CCode (cname = "alListeneri")]
		public static void set_parami (Enum param, Int value);
		[CCode (cname = "alListener3i")]
		public static void set_param3i (Enum param, Int value1, Int value2, Int value3);
		[CCode (cname = "alListeneriv")]
		public static void set_paramiv (Enum param, [CCode (array_length = false)] Int[] values);

		/** Get Listener parameters */
		[CCode (cname = "alGetListenerf")]
		public static void get_paramf (Enum param, out Float value);
		[CCode (cname = "alGetListener3f")]
		public static void get_param3f (Enum param, out Float value1, out Float value2, out Float value3);
		[CCode (cname = "alGetListenerfv")]
		public static void get_paramfv (Enum param, [CCode (array_length = false)] Float[] values);
		[CCode (cname = "alGetListeneri")]
		public static void get_parami (Enum param, out Int value);
		[CCode (cname = "alGetListener3i")]
		public static void get_param3i (Enum param, out Int value1, out Int value2, out Int value3);
		[CCode (cname = "alGetListeneriv")]
		public static void get_paramiv (Enum param, [CCode (array_length = false)] Int[] values);
	}

	[SimpleType]
	[CCode (cname = "ALuint", has_type_id = false)]
	public struct Source : Uint {
		/** Set Source parameters. */
		[CCode (cname = "alSourcef")]
		public void set_paramf (Enum param, Float value);
		[CCode (cname = "alSource3f")]
		public void set_param3f (Enum param, Float value1, Float value2, Float value3);
		[CCode (cname = "alSourcefv")]
		public void set_paramfv (Enum param, [CCode (array_length = false)] Float[] values);
		[CCode (cname = "alSourcei")]
		public void set_parami (Enum param, Int value);
		[CCode (cname = "alSource3i")]
		public void set_param3i (Enum param, Int value1, Int value2, Int value3);
		[CCode (cname = "alSourceiv")]
		public void set_paramiv (Enum param, [CCode (array_length = false)] Int[] values);

		/** Get Source parameters. */
		[CCode (cname = "alGetSourcef")]
		public void get_paramf (Enum param, out Float value);
		[CCode (cname = "alGetSource3f")]
		public void get_param3f (Enum param, out Float value1, out Float value2, out Float value3);
		[CCode (cname = "alGetSourcefv")]
		public void get_paramfv (Enum param, [CCode (array_length = false)] Float[] values);
		[CCode (cname = "alGetSourcei")]
		public void get_parami (Enum param, out Int value);
		[CCode (cname = "alGetSource3i")]
		public void get_param3i (Enum param, out Int value1, out Int value2, out Int value3);
		[CCode (cname = "alGetSourceiv")]
		public void get_paramiv (Enum param, [CCode (array_length = false)] Int[] values);

		/** Play, replay, or resume (if paused) a list of Sources */
		[CCode (cname = "alSourcePlayv")]
		public static void playv (Sizei n, [CCode (array_length = false)] Source[] sources);
		/** Stop a list of Sources */
		[CCode (cname = "alSourceStopv")]
		public static void stopv (Sizei n, [CCode (array_length = false)] Source[] sources);
		/** Rewind a list of Sources */
		[CCode (cname = "alSourceRewindv")]
		public static void rewindv (Sizei n, [CCode (array_length = false)] Source[] sources);
		/** Pause a list of Sources */
		[CCode (cname = "alSourcePausev")]
		public static void pausev (Sizei n, [CCode (array_length = false)] Source[] sources);

		/** Play, replay, or resume a Source */
		[CCode (cname = "alSourcePlay")]
		public void play ();
		/** Stop a Source */
		[CCode (cname = "alSourceStop")]
		public void stop ();
		/** Rewind a Source (set playback postiton to beginning) */
		[CCode (cname = "alSourceRewind")]
		public void rewind ();
		/** Pause a Source */
		[CCode (cname = "alSourcePause")]
		public void pause ();

		/** Queue buffers onto a source */
		[CCode (cname = "alSourceQueueBuffers")]
		public void queue_buffers (Sizei nb, [CCode (array_length = false)] Uint[] buffers);
		[CCode (cname = "alSourceQueueBuffers")]
		public void queue_buffer (Sizei nb, ref Uint buffer);
		/** Unqueue processed buffers from a source */
		[CCode (cname = "alSourceUnqueueBuffers")]
		public void unqueue_buffers (Sizei nb, [CCode (array_length = false)] Uint[] buffers);
		[CCode (cname = "alSourceUnqueueBuffers")]
		public void unqueue_buffer (Sizei nb, ref Uint buffer);
	}

	/** Create Source objects. */
	[CCode (cname = "alGenSources")]
	public void gen_sources (Sizei n, [CCode (array_length = false)] Source[] sources);
	/** Create Source object. */
	[CCode (cname = "alGenSources")]
	public void gen_source (Sizei n, out Source source);
	/** Delete Source objects. */
	[CCode (cname = "alDeleteSources")]
	public void delete_sources (Sizei n, [CCode (array_length = false)] Source[] sources);
	/** Delete Source object. */
	[CCode (cname = "alDeleteSources")]
	public void delete_source (Sizei n, ref Source source);
	/** Verify a handle is a valid Source. */
	[CCode (cname = "alIsSource")]
	public bool is_source (Uint source);

	[SimpleType]
	[CCode (cname = "ALuint", has_type_id = false)]
	public struct Buffer : Uint {
		/** Specifies the data to be copied into a buffer */
		[CCode (cname = "alBufferData")]
		public void set_data (Enum format, [CCode (array_length = false)] Short[] data, Sizei size, Sizei freq);

		/** Set Buffer parameters, */
		[CCode (cname = "alBufferf")]
		public void set_paramf (Enum param, Float value);
		[CCode (cname = "alBuffer3f")]
		public void set_param3f (Enum param, Float value1, Float value2, Float value3);
		[CCode (cname = "alBufferfv")]
		public void set_paramfv (Enum param, [CCode (array_length = false)] Float[] values);
		[CCode (cname = "alBufferi")]
		public void set_parami (Enum param, Int value);
		[CCode (cname = "alBuffer3i")]
		public void set_param3i (Enum param, Int value1, Int value2, Int value3);
		[CCode (cname = "alBufferiv")]
		public void set_paramiv (Enum param, [CCode (array_length = false)] Int[] values);

		/** Get Buffer parameters. */
		[CCode (cname = "alGetBufferf")]
		public void get_paramf (Enum param, out Float value);
		[CCode (cname = "alGetBuffer3f")]
		public void get_param3f (Enum param, out Float value1, out Float value2, out Float value3);
		[CCode (cname = "alGetBufferfv")]
		public void get_paramfv (Enum param, [CCode (array_length = false)] Float[] values);
		[CCode (cname = "alGetBufferi")]
		public void get_parami (Enum param, out Int value);
		[CCode (cname = "alGetBuffer3i")]
		public void get_param3i (Enum param, out Int value1, out Int value2, out Int value3);
		[CCode (cname = "alGetBufferiv")]
		public void get_paramiv (Enum param, [CCode (array_length = false)] Int[] values);
	}

	/** Create Buffer objects */
	[CCode (cname = "alGenBuffers")]
	public void gen_buffers (Sizei n, [CCode (array_length = false)] Buffer[] buffers);
	/** Create Buffer object */
	[CCode (cname = "alGenBuffers")]
	public void gen_buffer (Sizei n, out Buffer buffer);
	/** Delete Buffer objects */
	[CCode (cname = "alDeleteBuffers")]
	public void delete_buffers (Sizei n, [CCode (array_length = false)] Buffer[] buffers);
	/** Delete Buffer object */
	[CCode (cname = "alDeleteBuffers")]
	public void delete_buffer (Sizei n, ref Buffer buffer);
	/** Verify a handle is a valid Buffer */
	[CCode (cname = "alIsBuffer")]
	public bool is_buffer (Uint buffer);
}

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "alc.h")]
namespace ALC
{
	/** 8-bit boolean */
	[CCode (cname = "ALCboolean", has_type_id = false)]
	public struct Boolean : int8 {}

	/** character */
	[CCode (cname = "ALCchar", has_type_id = false)]
	public struct Char : char {}

	/** signed 8-bit 2's complement integer */
	[CCode (cname = "ALCbyte", has_type_id = false)]
	public struct Byte : int8 {}

	/** unsigned 8-bit integer */
	[CCode (cname = "ALCubyte", has_type_id = false)]
	public struct Ubyte : uint8 {}

	/** signed 16-bit 2's complement integer */
	[CCode (cname = "ALCshort", has_type_id = false)]
	public struct Short : int16 {}

	/** unsigned 16-bit integer */
	[CCode (cname = "ALCushort", has_type_id = false)]
	public struct Ushort : uint16 {}

	/** signed 32-bit 2's complement integer */
	[CCode (cname = "ALCint", has_type_id = false)]
	public struct Int : int32 {}

	/** unsigned 32-bit integer */
	[CCode (cname = "ALCuint", has_type_id = false)]
	public struct Uint : uint32 {}

	/** non-negative 32-bit binary integer size */
	[CCode (cname = "ALCsizei", has_type_id = false)]
	public struct Sizei : int32 {}

	/** enumerated 32-bit value */
	[CCode (cname = "ALCenum", has_type_id = false)]
	public struct Enum : int32 {}

	/** 32-bit IEEE754 floating-point */
	[CCode (cname = "ALCfloat", has_type_id = false)]
	public struct Float : float {}

	/** 64-bit IEEE754 floating-point */
	[CCode (cname = "ALCdouble", has_type_id = false)]
	public struct Double : double {}

	/** void type (for opaque pointers only) */
	[CCode (cname = "ALCvoid", has_type_id = false)]
	public struct Void {}

	/** Boolean False. */
	[CCode (cname = "ALC_FALSE")]
	public const Enum FALSE;

	/** Boolean True. */
	[CCode (cname = "ALC_TRUE")]
	public const Enum TRUE;

	/** Context attribute: <int> Hz. */
	[CCode (cname = "ALC_FREQUENCY")]
	public const Enum FREQUENCY;

	/** Context attribute: <int> Hz. */
	[CCode (cname = "ALC_REFRESH")]
	public const Enum REFRESH;

	/** Context attribute: AL_TRUE or AL_FALSE. */
	[CCode (cname = "ALC_SYNC")]
	public const Enum SYNC;

	/** Context attribute: <int> requested Mono (3D) Sources. */
	[CCode (cname = "ALC_MONO_SOURCES")]
	public const Enum MONO_SOURCES;

	/** Context attribute: <int> requested Stereo Sources. */
	[CCode (cname = "ALC_STEREO_SOURCES")]
	public const Enum STEREO_SOURCES;

	[CCode (cname = "ALCenum", cprefix = "ALC_", has_type_id = false)]
	public enum Error
	{
		/** No error. */
		NO_ERROR,
		/** Invalid device handle. */
		INVALID_DEVICE,
		/** Invalid context handle. */
		INVALID_CONTEXT,
		/** Invalid enum parameter passed to an ALC call. */
		INVALID_ENUM,
		/** Invalid value parameter passed to an ALC call. */
		INVALID_VALUE,
		/** Out of memory. */
		OUT_OF_MEMORY
	}

	/** Runtime ALC version. */
	[CCode (cname = "ALC_MAJOR_VERSION")]
	public const Enum MAJOR_VERSION;
	[CCode (cname = "ALC_MINOR_VERSION")]
	public const Enum MINOR_VERSION;

	/** Context attribute list properties. */
	[CCode (cname = "ALC_ATTRIBUTES_SIZE")]
	public const Enum ATTRIBUTES_SIZE;
	[CCode (cname = "ALC_ALL_ATTRIBUTES")]
	public const Enum ALL_ATTRIBUTES;

	/** String for the default device specifier. */
	[CCode (cname = "ALC_DEFAULT_DEVICE_SPECIFIER")]
	public const Enum DEFAULT_DEVICE_SPECIFIER;

	/**
	* String for the given device's specifier.
	*
	* If device handle is NULL, it is instead a null-char separated list of
	* strings of known device specifiers (list ends with an empty string).
	*/
	[CCode (cname = "ALC_DEVICE_SPECIFIER")]
	public const Enum DEVICE_SPECIFIER;
	/** String for space-separated list of ALC extensions. */
	[CCode (cname = "ALC_EXTENSIONS")]
	public const Enum EXTENSIONS;

	/** Capture extension */
	[CCode (cname = "ALC_EXT_CAPTURE")]
	public const Enum EXT_CAPTURE;

	/**
	* String for the given capture device's specifier.
	*
	* If device handle is NULL, it is instead a null-char separated list of
	* strings of known capture device specifiers (list ends with an empty string).
	*/
	[CCode (cname = "ALC_CAPTURE_DEVICE_SPECIFIER")]
	public const Enum CAPTURE_DEVICE_SPECIFIER;
	/** String for the default capture device specifier. */
	[CCode (cname = "ALC_CAPTURE_DEFAULT_DEVICE_SPECIFIER")]
	public const Enum CAPTURE_DEFAULT_DEVICE_SPECIFIER;
	/** Number of sample frames available for capture. */
	[CCode (cname = "ALC_CAPTURE_SAMPLES")]
	public const Enum CAPTURE_SAMPLES;

	/** Enumerate All extension */
	[CCode (cname = "ALC_ENUMERATE_ALL_EXT")]
	public const Enum ENUMERATE_ALL_EXT;
	/** String for the default extended device specifier. */
	[CCode (cname = "ALC_DEFAULT_ALL_DEVICES_SPECIFIER")]
	public const Enum DEFAULT_ALL_DEVICES_SPECIFIER;

	/**
	* String for the given extended device's specifier.
	*
	* If device handle is NULL, it is instead a null-char separated list of
	* strings of known extended device specifiers (list ends with an empty string).
	*/
	[CCode (cname = "ALC_ALL_DEVICES_SPECIFIER")]
	public const Enum ALL_DEVICES_SPECIFIER;


	/** Context management. */
	[Compact]
	[CCode (cname = "ALCcontext", has_type_id = false, free_function = "alcDestroyContext")]
	public class Context {
		[CCode (cname = "alcCreateContext")]
		public Context (Device device, [CCode (array_length = false)] Int[] ? attrlist);

		[CCode (cname = "alcMakeContextCurrent")]
		public bool make_current ();

		[CCode (cname = "alcProcessContext")]
		public void process ();

		[CCode (cname = "alcSuspendContext")]
		public void suspend ();

		[CCode (cname = "alcDestroyContext")]
		public void destroy ();

		[CCode (cname = "alcGetContextsDevice")]
		public Device get_contexts_device ();
	}

	[CCode (cname = "alcGetCurrentContext")]
	public static Context get_current_context ();

	/** Device management. */
	[Compact]
	[CCode (cname = "ALCdevice", has_type_id = false, free_function = "alcCloseDevice")]
	public class Device {
		[CCode (cname = "alcOpenDevice")]
		public Device (string? devicename);

		/**
		* Extension support.
		*
		* Query for the presence of an extension, and obtain any appropriate
		* function pointers and enum values.
		*/
		[CCode (cname = "alcIsExtensionPresent")]
		public bool is_extension_present (string extname);
		[CCode (cname = "alcGetProcAddress")]
		public void* get_proc_address (string funcname);
		[CCode (cname = "alcGetEnumValue")]
		public Enum get_enum_value (string enumname);

		/** Query function. */
		[CCode (cname = "alcGetString")]
		public unowned string? get_string (Enum param);
		[CCode (cname = "alcGetIntegerv")]
		public void get_integerv (Enum param, Sizei size, [CCode (array_length = false)] Int[] values);

		/**
		* Error support.
		*
		* Obtain the most recent Device error.
		*/
		[CCode (cname = "alcGetError")]
		public Error get_error ();

		[CCode (cname = "alcCloseDevice")]
		public bool destroy ();
	}

	[Compact]
	[CCode (cname = "ALCdevice", has_type_id = false, free_function = "alcCaptureCloseDevice")]
	public class CaptureDevice : Device {
		/** Capture function. */
		[CCode (cname = "alcCaptureOpenDevice")]
		public CaptureDevice (string devicename, Uint frequency, Enum format, Sizei buffersize);

		[CCode (cname = "alcCaptureCloseDevice")]
		public bool destroy ();

		[CCode (cname = "alcCaptureStart")]
		public void start ();

		[CCode (cname = "alcCaptureStop")]
		public void stop ();

		[CCode (cname = "alcCaptureSamples")]
		public void samples ([CCode (array_length = false)] uint8[] buffer, Sizei samples);
	}
}


