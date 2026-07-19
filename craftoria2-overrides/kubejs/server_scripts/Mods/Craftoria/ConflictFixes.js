ServerEvents.recipes(e => {

  // Croptopia
  // Croptopia's knife recipe conflicts with Chisel's iron chisel recipe
  e.shaped('croptopia:knife', ['AA ', 'B  ', '   '], {
    A: 'minecraft:iron_ingot',
    B: 'minecraft:stick',
  }).id('croptopia:knife');
  
});