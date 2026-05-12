<script lang="ts">
  import { IconCheck, IconDroplet, IconBolt, IconInfoCircle, IconAlertCircle, IconGauge, IconBanana } from '@tabler/icons-svelte-runes';
  import { tweened } from 'svelte/motion';
  import { linear } from 'svelte/easing';

  console.log('All Cyclists Are Beautiful. Ride safe. <3');
  
  // Nutrition science data
  const CARB_RANGES = {
    low: { min: 30, max: 45, label: 'Low' },
    moderate: { min: 45, max: 60, label: 'Moderate' },
    high: { min: 60, max: 90, label: 'High' },
    extreme: { min: 90, max: 120, label: 'Extreme' }
  } as const;

  const FLUID_RANGES = {
    low: { min: 0.4, max: 0.5 },
    moderate: { min: 0.5, max: 0.7 },
    high: { min: 0.7, max: 1.0 },
    extreme: { min: 1.0, max: 1.2 }
  } as const;

  // Reactive state
  let distance = 50;
  let duration = 4;
  let weight = 70;
  let intensity: keyof typeof CARB_RANGES = 'moderate';
  
  // Weight factor for scaling recommendations (normalized to 70kg)
  $: weightFactor = weight > 0 ? weight / 70 : 1;
  
  // Computed values
  $: baseCarbs = (CARB_RANGES[intensity].min + CARB_RANGES[intensity].max) / 2;
  $: carbsPerHour = Math.round(baseCarbs * weightFactor);
  $: speed = distance > 0 && duration > 0 ? Math.round(distance / duration) : 0;
  $: baseFluid = (FLUID_RANGES[intensity].min + FLUID_RANGES[intensity].max) / 2;
  $: fluidPerHour = baseFluid * weightFactor;
  $: totalCarbs = Math.round(carbsPerHour * duration);
  $: totalFluid = fluidPerHour * duration;

  // Animated display values
  const animatedCarbs = tweened(carbsPerHour, { duration: 400, easing: linear });
  const animatedFluid = tweened(fluidPerHour, { duration: 400, easing: linear });
  const animatedSpeed = tweened(speed, { duration: 400, easing: linear });
  const animatedTotalCarbs = tweened(totalCarbs, { duration: 400, easing: linear });
  const animatedTotalFluid = tweened(totalFluid, { duration: 400, easing: linear });

  // Update animations when values change
  $: animatedCarbs.set(carbsPerHour);
  $: animatedFluid.set(fluidPerHour);
  $: animatedSpeed.set(speed);
  $: animatedTotalCarbs.set(totalCarbs);
  $: animatedTotalFluid.set(totalFluid);

  // Funny speed slogans - Animal themed with Wikipedia links
  const animalLinks = {
    'Turtle pace': 'https://en.wikipedia.org/wiki/Turtle',
    'Penguin cruise': 'https://en.wikipedia.org/wiki/Penguin',
    'Gazelle pace': 'https://en.wikipedia.org/wiki/Gazelle',
    'Cheetah chase': 'https://en.wikipedia.org/wiki/Cheetah',
    'Falcon flight': 'https://en.wikipedia.org/wiki/Falcon',
    'Peregrine speed': 'https://en.wikipedia.org/wiki/Peregrine_falcon',
    'Greyhound sprint': 'https://en.wikipedia.org/wiki/Greyhound'
  };

  $: speedSlogan = speed === 0 ? '' :
    speed < 10 ? 'Turtle pace' :
    speed < 15 ? 'Penguin cruise' :
    speed < 20 ? 'Gazelle pace' :
    speed < 25 ? 'Cheetah chase' :
    speed < 30 ? 'Falcon flight' :
    speed < 40 ? 'Peregrine speed' :
    'Greyhound sprint';
  
  // Progress indicator
  $: scaledCarbMin = Math.round(CARB_RANGES[intensity].min * weightFactor);
  $: scaledCarbMax = Math.round(CARB_RANGES[intensity].max * weightFactor);
  $: scaledFluidMin = FLUID_RANGES[intensity].min * weightFactor;
  $: scaledFluidMax = FLUID_RANGES[intensity].max * weightFactor;
  $: carbProgress = ((carbsPerHour - scaledCarbMin) / (scaledCarbMax - scaledCarbMin)) * 100;
  $: fluidProgress = ((fluidPerHour - scaledFluidMin) / (scaledFluidMax - scaledFluidMin)) * 100;
</script>

<main class="min-h-screen bg-[--color-canvas]">
  <div class="max-w-6xl mx-auto p-sm md:p-md lg:p-lg fade-in">
    
    <!-- Main Title -->
    <div class="text-center mb-section">
      <div class="flex items-center justify-center gap-md mb-md">
        <IconBanana class="w-10 h-10 md:w-12 md:h-12 text-[--color-info] banana-animate" />
        <h1 class="text-heading-xl md:text-display-campaign text-[--color-ink] font-heavy">
          BananaSprocket
        </h1>
      </div>
    </div>

    <!-- How To Section -->
    <div class="card-soft rounded-sm p-lg md:p-xl mb-section">
      <div class="grid grid-cols-1 md:grid-cols-3 gap-lg relative">
        <!-- Connector line (hidden on mobile, visible on md+) -->
        <div class="hidden md:block absolute left-0 right-0 top-6 h-px bg-[--color-hairline]"></div>
        
        <!-- Step 1 -->
        <div class="space-y-sm relative z-10">
          <div class="w-8 h-8 rounded-full bg-[--color-info]/10 border border-[--color-info]/30 flex items-center justify-center mb-sm">
            <span class="text-lg font-bold text-[--color-info]">1</span>
          </div>
          <h3 class="text-body-strong font-bold text-[--color-ink]">Enter your data</h3>
          <p class="text-caption-md text-[--color-charcoal]">
            Enter distance, duration, and your weight to get personalized recommendations.
          </p>
        </div>
        
        <!-- Step 2 -->
        <div class="space-y-sm relative z-10">
          <div class="w-8 h-8 rounded-full bg-[--color-info]/10 border border-[--color-info]/30 flex items-center justify-center mb-sm">
            <span class="text-lg font-bold text-[--color-info]">2</span>
          </div>
          <h3 class="text-body-strong font-bold text-[--color-ink]">Choose intensity</h3>
          <p class="text-caption-md text-[--color-charcoal]">
            Select your training intensity - from low to extreme for optimal values.
          </p>
        </div>
        
        <!-- Step 3 -->
        <div class="space-y-sm relative z-10">
          <div class="w-8 h-8 rounded-full bg-[--color-info]/10 border border-[--color-info]/30 flex items-center justify-center mb-sm">
            <span class="text-lg font-bold text-[--color-info]">3</span>
          </div>
          <h3 class="text-body-strong font-bold text-[--color-ink]">Read results</h3>
          <p class="text-caption-md text-[--color-charcoal]">
            Get your personal carbohydrate and fluid recommendations per hour.
          </p>
        </div>
      </div>
    </div>

    <!-- Input Card -->
    <div class="bg-[--color-canvas] border border-[--color-hairline-soft] rounded-sm p-lg md:p-xl mb-section">
      <div class="grid grid-cols-1 md:grid-cols-3 gap-lg">
        
        <!-- Distance Input -->
        <div class="space-y-sm">
          <label for="distance" class="text-caption-md text-[--color-ink]">
            Distance
          </label>
          <div class="flex items-center gap-sm">
            <input
              id="distance"
              type="number"
              bind:value={distance}
              min="1"
              max="500"
              step="1"
              class="search-pill flex-1"
            />
            <span class="text-caption-sm text-[--color-mute] whitespace-nowrap">km</span>
          </div>
        </div>

        <!-- Duration Input -->
        <div class="space-y-sm">
          <label for="duration" class="text-caption-md text-[--color-ink]">
            Duration
          </label>
          <div class="flex items-center gap-sm">
            <input
              id="duration"
              type="number"
              bind:value={duration}
              min="0.5"
              max="24"
              step="0.5"
              class="search-pill flex-1"
            />
            <span class="text-caption-sm text-[--color-mute] whitespace-nowrap">h</span>
          </div>
        </div>

        <!-- Weight Input -->
        <div class="space-y-sm">
          <label for="weight" class="text-caption-md text-[--color-ink]">
            Weight
          </label>
          <div class="flex items-center gap-sm">
            <input
              id="weight"
              type="number"
              bind:value={weight}
              min="40"
              max="150"
              step="1"
              class="search-pill flex-1"
            />
            <span class="text-caption-sm text-[--color-mute] whitespace-nowrap">kg</span>
          </div>
        </div>
      </div>
      
      <!-- Intensity Chips -->
      <div class="mt-lg">
        <label class="text-caption-md text-[--color-ink] mb-sm block">Intensity</label>
        <div class="flex flex-wrap gap-sm">
          {#each Object.entries(CARB_RANGES) as [key, value]}
            <button
              class="filter-chip {intensity === key ? 'filter-chip-active' : ''}"
              on:click={() => intensity = key}
            >
              {value.label}
            </button>
          {/each}
        </div>
      </div>
      
    </div>

    <!-- Speed Card -->
    {#if speed > 0}
      <a href={animalLinks[speedSlogan]} target="_blank" rel="noopener noreferrer" class="block mb-section">
        <div class="card p-md hover:border-[--color-info] transition-colors duration-200">
          <div class="flex items-center gap-md">
            <IconGauge class="w-8 h-8 text-[--color-info] flex-shrink-0" />
            <div class="flex-1">
              <p class="text-heading-md text-[--color-ink]">Average speed ~{$animatedSpeed} km/h</p>
            </div>
            <span class="badge-black whitespace-nowrap">{speedSlogan}</span>
          </div>
        </div>
      </a>
    {/if}

    <!-- Results Grid -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-lg mb-section">
      
      <!-- Carbs Result Card -->
      <div class="card p-lg">
        <div class="flex items-start gap-md mb-lg">
          <div class="w-12 h-12 rounded-sm bg-[--color-success] flex items-center justify-center flex-shrink-0">
            <IconBolt class="w-7 h-7 text-[--color-on-primary]" />
          </div>
          <div class="min-w-0">
            <h3 class="text-heading-lg font-bold text-[--color-ink]">Carbohydrates</h3>
            <p class="text-caption-sm text-[--color-mute]">
              Per hour for optimal performance
            </p>
          </div>
        </div>
        
        <div class="mb-lg">
          <div class="flex items-baseline gap-sm">
            <span class="text-7xl md:text-8xl font-extra-bold text-[--color-ink]">{Math.round($animatedCarbs)}</span>
            <span class="text-3xl text-[--color-mute]">g/h</span>
          </div>
          <div class="flex items-center gap-sm mt-sm">
            <span class="text-caption-sm text-[--color-charcoal]">Range:</span>
            <span class="text-body-strong text-[--color-ink]">
              {scaledCarbMin}&nbsp;-&nbsp;{scaledCarbMax}g
            </span>
          </div>
        </div>

        <!-- Progress Bar -->
        <div class="relative h-2 bg-[--color-soft-cloud] rounded-full overflow-hidden mt-md">
          <div 
            class="absolute left-0 top-0 bottom-0 bg-[--color-success] transition-all duration-300"
            style="width: {carbProgress}%"
          ></div>
        </div>
      </div>

      <!-- Fluid Result Card -->
      <div class="card p-lg">
        <div class="flex items-start gap-md mb-lg">
          <div class="w-12 h-12 rounded-sm bg-[--color-info] flex items-center justify-center flex-shrink-0">
            <IconDroplet class="w-7 h-7 text-[--color-on-primary]" />
          </div>
          <div class="min-w-0">
            <h3 class="text-heading-lg font-bold text-[--color-ink]">Fluids</h3>
            <p class="text-caption-sm text-[--color-mute]">
              Per hour for hydration
            </p>
          </div>
        </div>
        
        <div class="mb-lg">
          <div class="flex items-baseline gap-sm">
            <span class="text-7xl md:text-8xl font-extra-bold text-[--color-ink]">{$animatedFluid.toFixed(1)}</span>
            <span class="text-3xl text-[--color-mute]">L/h</span>
          </div>
          <div class="flex items-center gap-sm mt-sm">
            <span class="text-caption-sm text-[--color-charcoal]">Range:</span>
            <span class="text-body-strong text-[--color-ink]">
              {scaledFluidMin.toFixed(1)}&nbsp;-&nbsp;{scaledFluidMax.toFixed(1)}L
            </span>
          </div>
        </div>

        <!-- Progress Bar -->
        <div class="relative h-2 bg-[--color-soft-cloud] rounded-full overflow-hidden mt-md">
          <div 
            class="absolute left-0 top-0 bottom-0 bg-[--color-info] transition-all duration-300"
            style="width: {fluidProgress}%"
          ></div>
        </div>
      </div>
    </div>

    <!-- Totals Section - Dark Campaign Style -->
    <div class="card-campaign rounded-sm p-lg md:p-xl mb-section">
      <h2 class="text-heading-lg mb-lg text-[--color-on-primary]">
        Total needs for {duration} hours
      </h2>
      
      <div class="grid grid-cols-2 gap-md">
        <div class="bg-[--color-on-primary] rounded-md p-md text-center">
          <div class="text-4xl md:text-5xl font-extra-bold text-[--color-ink] mb-xs">
            {Math.round($animatedTotalCarbs)}g
          </div>
          <div class="text-caption-sm text-[--color-charcoal]">
            Carbohydrates
          </div>
        </div>
        <div class="bg-[--color-on-primary] rounded-md p-md text-center">
          <div class="text-4xl md:text-5xl font-extra-bold text-[--color-info] mb-xs">
            {$animatedTotalFluid.toFixed(1)}L
          </div>
          <div class="text-caption-sm text-[--color-charcoal]">
            Fluids
          </div>
        </div>
      </div>
    </div>

    <!-- Tips Section - 50/50 Grid -->
    <div class="card-soft p-lg rounded-sm mt-section">
      <h3 class="text-heading-md text-[--color-ink] mb-lg">
        Pro Tips
      </h3>
      
      <div class="grid grid-cols-1 md:grid-cols-2 gap-lg">
        <!-- Left Column -->
        <div class="space-y-lg">
          <div class="flex gap-md items-start">
            <div class="w-8 h-8 rounded-full bg-[--color-success] flex items-center justify-center flex-shrink-0 mt-1">
              <IconCheck class="w-5 h-5 text-[--color-on-primary]" />
            </div>
            <div>
              <h4 class="text-body-strong text-[--color-ink] mb-xs">Regular intake</h4>
              <p class="text-caption-md text-[--color-charcoal]">
                Take ~15-25g of carbohydrates every 15-20 minutes to keep your blood sugar stable.
              </p>
            </div>
          </div>

          <div class="flex gap-md items-start">
            <div class="w-8 h-8 rounded-full bg-[--color-sale] flex items-center justify-center flex-shrink-0 mt-1">
              <IconAlertCircle class="w-5 h-5 text-[--color-on-primary]" />
            </div>
            <div>
              <h4 class="text-body-strong text-[--color-ink] mb-xs">Electrolytes</h4>
              <p class="text-caption-md text-[--color-charcoal]">
                On rides over 2 hours: supplement with electrolytes (sodium, magnesium, potassium).
              </p>
            </div>
          </div>
        </div>
        
        <!-- Right Column -->
        <div class="space-y-lg">
          <div class="flex gap-md items-start">
            <div class="w-8 h-8 rounded-full bg-[--color-info] flex items-center justify-center flex-shrink-0 mt-1">
              <IconInfoCircle class="w-5 h-5 text-[--color-on-primary]" />
            </div>
            <div>
              <h4 class="text-body-strong text-[--color-ink] mb-xs">Fluid adjustment</h4>
              <p class="text-caption-md text-[--color-charcoal]">
                In heat or heavy sweating, increase intake by 0.2-0.4L per hour.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>


  </div>
</main>
